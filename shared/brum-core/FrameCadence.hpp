#pragma once
#include <algorithm>
#include <cmath>

namespace brum {
// Converts display callbacks into emulated frames. The display refresh is not
// an emulation-speed limit: a faster core may run multiple frames per callback.
class FrameCadence {
public:
    void setRate(double framesPerSecond) {
        rate_ = std::isfinite(framesPerSecond) && framesPerSecond >= 1 && framesPerSecond <= 1000
            ? framesPerSecond : 60;
        reset();
    }
    double rate() const { return rate_; }
    void reset() { last_ = -1; remainder_ = 0; }
    unsigned framesDue(double now) {
        if (!std::isfinite(now) || now < 0) { reset(); return 0; }
        if (last_ < 0 || now < last_) { last_ = now; return 1; }
        // A long host suspension must not produce a catch-up storm. This
        // bounds *stale* work, not the sustainable frame rate of the core.
        const double elapsed = std::min(now - last_, 0.1);
        last_ = now;
        remainder_ += elapsed * rate_;
        const unsigned due = static_cast<unsigned>(std::floor(remainder_ + 1e-9));
        remainder_ -= due;
        return due;
    }
private:
    double rate_ = 60;
    double last_ = -1;
    double remainder_ = 0;
};
} // namespace brum
