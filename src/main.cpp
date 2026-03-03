#include <opus/opus.h>
#include <opus/opusenc.h>
#include <opus/opusfile.h>

#include <pybind11/numpy.h>
#include <pybind11/pybind11.h>

#include <cstdint>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace py = pybind11;

namespace {
constexpr int kMaxSamplesPerChannel = 120 * 48;

[[noreturn]] void throw_value_error(const char *msg) {
    throw py::value_error(msg);
}

std::string ope_error_message(int err) {
    const char *err_str = ope_strerror(err);
    if (err_str == nullptr) {
        return "Unknown Opus encoder error";
    }
    return std::string(err_str);
}

}  // namespace

class OpusBufferedEncoder {
   public:
    OpusBufferedEncoder(int sample_rate,
                        int channels,
                        int bitrate = OPUS_AUTO,
                        int signal_type = 0,
                        int encoder_complexity = 10,
                        int decision_delay = 0)
        : encoder_(nullptr), comments_(nullptr), channels_(channels), has_written_(false), flushed_(false) {
        if (channels < 1 || channels > 8) {
            throw_value_error("Invalid channels, must be in range [1, 8].");
        }
        if ((bitrate < 500 || bitrate > 512000) && bitrate != OPUS_BITRATE_MAX && bitrate != OPUS_AUTO) {
            throw_value_error("Invalid bitrate, must be between 500 and 512000, OPUS_BITRATE_MAX, or OPUS_AUTO.");
        }
        if (sample_rate < 8000 || sample_rate > 48000) {
            throw_value_error("Invalid sample_rate, must be in range [8000, 48000].");
        }
        if (encoder_complexity < 0 || encoder_complexity > 10) {
            throw_value_error("Invalid encoder_complexity, must be in range [0, 10].");
        }
        if (decision_delay < 0) {
            throw_value_error("Invalid decision_delay, must be >= 0.");
        }

        int error = OPE_OK;
        comments_ = ope_comments_create();
        if (comments_ == nullptr) {
            throw_value_error("Failed to allocate Opus comments.");
        }

        encoder_ = ope_encoder_create_pull(comments_, sample_rate, channels, 0, &error);
        if (error != OPE_OK || encoder_ == nullptr) {
            close();
            throw py::value_error(("Failed to create Opus encoder: " + ope_error_message(error)).c_str());
        }

        if (ope_encoder_ctl(encoder_, OPUS_SET_BITRATE(bitrate)) != OPE_OK) {
            close();
            throw_value_error("Could not set bitrate.");
        }

        opus_int32 opus_signal_type = OPUS_AUTO;
        switch (signal_type) {
            case 0:
                opus_signal_type = OPUS_AUTO;
                break;
            case 1:
                opus_signal_type = OPUS_SIGNAL_MUSIC;
                break;
            case 2:
                opus_signal_type = OPUS_SIGNAL_VOICE;
                break;
            default:
                close();
                throw_value_error("Invalid signal_type, must be 0 (auto), 1 (music), or 2 (voice).");
        }

        if (ope_encoder_ctl(encoder_, OPUS_SET_SIGNAL(opus_signal_type)) != OPE_OK) {
            close();
            throw_value_error("Could not set signal type.");
        }
        if (ope_encoder_ctl(encoder_, OPUS_SET_COMPLEXITY(encoder_complexity)) != OPE_OK) {
            close();
            throw_value_error("Could not set encoder complexity.");
        }
        if (ope_encoder_ctl(encoder_, OPE_SET_DECISION_DELAY(decision_delay)) != OPE_OK) {
            close();
            throw_value_error("Could not set decision delay.");
        }
    }

    py::bytes write(const py::array_t<int16_t, py::array::c_style | py::array::forcecast> &buffer) {
        ensure_open();
        if (flushed_) {
            throw_value_error("flush() was already called; create a new encoder instance.");
        }
        if (buffer.ndim() != 2 || buffer.shape(1) != channels_) {
            throw_value_error("Buffer must have shape [samples, channels] matching constructor channels.");
        }
        if (buffer.shape(0) == 0) {
            return py::bytes();
        }

        const int16_t *data = buffer.data();
        const auto samples = static_cast<int>(buffer.shape(0));
        const int ret = ope_encoder_write(encoder_, data, samples);
        if (ret != OPE_OK) {
            throw py::value_error(("Encoding failed: " + ope_error_message(ret)).c_str());
        }

        std::vector<unsigned char> encoded_data;
        unsigned char *packet = nullptr;
        opus_int32 len = 0;
        while (ope_encoder_get_page(encoder_, &packet, &len, 1) != 0) {
            encoded_data.insert(encoded_data.end(), packet, packet + len);
            has_written_ = true;
        }

        return py::bytes(reinterpret_cast<const char *>(encoded_data.data()), encoded_data.size());
    }

    py::bytes flush() {
        ensure_open();
        if (!has_written_) {
            throw_value_error("You must call write() at least once before flush().");
        }
        if (flushed_) {
            throw_value_error("flush() can only be called once.");
        }

        const int ret = ope_encoder_drain(encoder_);
        if (ret != OPE_OK) {
            throw py::value_error(("Draining failed: " + ope_error_message(ret)).c_str());
        }

        std::vector<unsigned char> encoded_data;
        unsigned char *packet = nullptr;
        opus_int32 len = 0;
        while (ope_encoder_get_page(encoder_, &packet, &len, 1) != 0) {
            encoded_data.insert(encoded_data.end(), packet, packet + len);
        }
        flushed_ = true;
        return py::bytes(reinterpret_cast<const char *>(encoded_data.data()), encoded_data.size());
    }

    void close() {
        if (encoder_ != nullptr) {
            ope_encoder_destroy(encoder_);
            encoder_ = nullptr;
        }
        if (comments_ != nullptr) {
            ope_comments_destroy(comments_);
            comments_ = nullptr;
        }
    }

    ~OpusBufferedEncoder() { close(); }

   private:
    void ensure_open() const {
        if (encoder_ == nullptr) {
            throw_value_error("Encoder is closed.");
        }
    }

    OggOpusEnc *encoder_;
    OggOpusComments *comments_;
    int channels_;
    bool has_written_;
    bool flushed_;
};

class OpusBufferedDecoder {
   public:
    OpusBufferedDecoder() = default;

    py::array_t<int16_t> decode(const py::bytes &opus_data) const {
        std::string encoded = opus_data;
        if (encoded.empty()) {
            return py::array_t<int16_t>({0, 0});
        }
        if (encoded.size() > static_cast<size_t>(std::numeric_limits<opus_int32>::max())) {
            throw_value_error("Input is too large to decode.");
        }

        int error = 0;
        OggOpusFile *opus_file = op_open_memory(
            reinterpret_cast<const unsigned char *>(encoded.data()), static_cast<opus_int32>(encoded.size()), &error);
        if (opus_file == nullptr) {
            throw py::value_error(("Failed to parse opus stream, op_open_memory error=" + std::to_string(error)).c_str());
        }

        const int channels = op_channel_count(opus_file, -1);
        if (channels <= 0 || channels > 8) {
            op_free(opus_file);
            throw_value_error("Invalid channel count from opus stream.");
        }

        std::vector<int16_t> pcm;
        std::vector<int16_t> frame(static_cast<size_t>(kMaxSamplesPerChannel * channels));

        while (true) {
            const int samples = op_read(opus_file, frame.data(), static_cast<int>(frame.size()), nullptr);
            if (samples == 0) {
                break;
            }
            if (samples < 0) {
                op_free(opus_file);
                throw py::value_error(("Decode failed, op_read error=" + std::to_string(samples)).c_str());
            }
            pcm.insert(pcm.end(), frame.begin(), frame.begin() + static_cast<size_t>(samples * channels));
        }

        op_free(opus_file);

        const auto sample_count = static_cast<ssize_t>(pcm.size() / static_cast<size_t>(channels));
        py::array_t<int16_t> output({sample_count, static_cast<ssize_t>(channels)});
        if (!pcm.empty()) {
            std::memcpy(output.mutable_data(), pcm.data(), pcm.size() * sizeof(int16_t));
        }
        return output;
    }
};

PYBIND11_MODULE(opuscodec, m) {
    m.doc() = "Python bindings for opusenc/opusdec with vendored libopus builds";

    py::class_<OpusBufferedEncoder>(m, "OpusBufferedEncoder")
        .def(py::init<int, int, int, int, int, int>(),
             py::arg("sample_rate"),
             py::arg("channels"),
             py::arg("bitrate") = OPUS_AUTO,
             py::arg("signal_type") = 0,
             py::arg("encoder_complexity") = 10,
             py::arg("decision_delay") = 0)
        .def("write", &OpusBufferedEncoder::write, py::arg("buffer"))
        .def("flush", &OpusBufferedEncoder::flush)
        .def("close", &OpusBufferedEncoder::close);

    py::class_<OpusBufferedDecoder>(m, "OpusBufferedDecoder")
        .def(py::init<>())
        .def("decode", &OpusBufferedDecoder::decode, py::arg("opus_data"));

    m.def("opus_version", []() { return std::string(opus_get_version_string()); });
#if defined(OPUSCODEC_QEXT_ENABLED)
    m.def("qext_enabled", []() { return true; });
#else
    m.def("qext_enabled", []() { return false; });
#endif
}
