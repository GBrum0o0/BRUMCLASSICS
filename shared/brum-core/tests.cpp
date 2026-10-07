#include "ScreenManager.hpp"
#include "InputState.hpp"
#include "N64Input.hpp"
#include "VirtualControlProfile.hpp"
#include "VirtualControlInput.hpp"
#include "../../ios/BRUMCLASSICSMobile/Libretro/BrumScreenProfiles.hpp"
#include <cstdlib>
#include <iostream>
#include <limits>

static unsigned checks = 0;
static void check(bool value) {
    ++checks;
    if (!value) { std::cerr << "Failed check " << checks << '\n'; std::exit(1); }
}
static bool near(double a, double b) { return std::abs(a - b) < 1e-8; }
static brum::Point rotated(brum::Point p, unsigned turns) {
    switch (turns) {
        case 1: return {1 - p.y, p.x};
        case 2: return {1 - p.x, 1 - p.y};
        case 3: return {p.y, 1 - p.x};
        default: return p;
    }
}
int main() {
    using namespace brum;
    for (const auto& core : {"skyemu", "azahar"}) {
        ScreenManager manager;
        manager.screens = libretroScreens(core, core == std::string("skyemu") ? 256 : 400,
                                         core == std::string("skyemu") ? 384 : 480);
        check(manager.screens.size() == 2);
        for (unsigned layout = 0; layout < 8; ++layout) {
            manager.layout = static_cast<Layout>(layout);
            for (unsigned rotation = 0; rotation < 4; ++rotation) {
                manager.quarterTurns = rotation;
                for (double scale : {0.25, 0.75, 1.0}) {
                    manager.scale = scale;
                    const Rect viewport {31, 57, 900, 600};
                    auto placements = manager.place(viewport);
                    check(placements.size() == (layout == 4 || layout == 5 ? 1u : 2u));
                    check(placements.front().screen.id == (layout == 1 || layout == 3 || layout == 5 || layout == 7 ? "secondary" : "primary"));
                    for (const auto& p : placements) {
                        check(p.frame.x >= viewport.x - 1e-8 && p.frame.y >= viewport.y - 1e-8);
                        check(p.frame.x + p.frame.width <= viewport.x + viewport.width + 1e-8);
                        check(p.frame.y + p.frame.height <= viewport.y + viewport.height + 1e-8);
                        const double ratio = rotation % 2 ? p.screen.height / p.screen.width : p.screen.width / p.screen.height;
                        check(near(p.frame.width / p.frame.height, ratio));
                        // Interior grid avoids ambiguous shared edges between adjacent screens.
                        for (double x : {0.001, 0.25, 0.5, 0.75, 0.999}) {
                            for (double y : {0.001, 0.25, 0.5, 0.75, 0.999}) {
                                auto position = rotated({x, y}, rotation);
                                auto touch = ScreenManager::hitTest({p.frame.x + position.x * p.frame.width,
                                                                    p.frame.y + position.y * p.frame.height}, placements);
                                check(touch.pressed == p.screen.touch);
                                if (!touch.pressed) continue;
                                check(touch.screenID == p.screen.id);
                                check(near(touch.local.x, x) && near(touch.local.y, y));
                                check(near(touch.atlas.x, p.screen.crop.x + x * p.screen.crop.width));
                                check(near(touch.atlas.y, p.screen.crop.y + y * p.screen.crop.height));
                            }
                        }
                    }
                    check(!ScreenManager::hitTest({-1, -1}, placements).pressed);
                }
            }
        }
    }
    ScreenManager manager;
    check(manager.place({0, 0, 800, 600}).empty());
    manager.screens = libretroScreens("unknown", 320, 240);
    check(manager.screens.size() == 1 && !manager.screens[0].touch);
    manager.layout = Layout::secondaryOnly;
    check(manager.place({0, 0, 800, 600}).empty());
    manager.layout = Layout::vertical;
    manager.screens.push_back({"second", "texture2", {0, 0, 1, 1}, 100, 100, true});
    manager.screens.push_back({"third", "texture3", {0, 0, 1, 1}, 200, 100, false});
    check(manager.place({0, 0, 800, 600}).size() == 3);
    manager.screenDisplays["second"] = "phone";
    check(manager.place({0, 0, 800, 600}).size() == 2);
    manager.displayID = "phone";
    auto remote = manager.place({0, 0, 800, 600});
    check(remote.size() == 1 && remote[0].screen.id == "second");
    manager.displayID = "missing";
    check(manager.place({0, 0, 800, 600}).empty());
    manager.displayID = "local";
    check(manager.place({0, 0, 0, 600}).empty());
    manager.scale = std::numeric_limits<double>::quiet_NaN();
    check(manager.place({0, 0, 800, 600}).empty());
    manager.scale = 1;
    manager.screens[0].width = -1;
    check(manager.place({0, 0, 800, 600}).empty());

    // One-screen FIT must be the largest undistorted image inside the useful
    // area; CROP is explicit, and the inverse rejects letterbox and crop.
    const Rect wide {15, 25, 1600, 900};
    const auto fit43 = calculateViewport(wide, 640, 480);
    check(fit43.valid() && near(fit43.frame.height, 900));
    check(near(fit43.frame.width / fit43.frame.height, 4.0 / 3.0));
    check(fit43.frame.x >= wide.x && fit43.frame.x + fit43.frame.width <= wide.x + wide.width);
    check(!fit43.toContent({wide.x + 1, wide.y + 1}).has_value());
    const auto centerTouch = fit43.toContent(fit43.toDisplay({0.5, 0.5}));
    check(centerTouch.has_value() && near(centerTouch->x, 0.5) && near(centerTouch->y, 0.5));
    const Rect tall {47, 31, 600, 900};
    const auto fit169 = calculateViewport(tall, 1920, 1080);
    check(fit169.valid() && near(fit169.frame.width, 600));
    check(near(fit169.frame.width / fit169.frame.height, 16.0 / 9.0));
    check(fit169.frame.y >= tall.y && fit169.frame.y + fit169.frame.height <= tall.y + tall.height);
    const auto cropped = calculateViewport(wide, 640, 480, ScaleMode::crop);
    check(cropped.valid() && near(cropped.frame.width, wide.width) && cropped.frame.height > wide.height);
    check(!cropped.toContent({cropped.frame.x + 1, cropped.frame.y + 1}).has_value());
    const auto integer = calculateViewport({0, 0, 850, 650}, 320, 240, ScaleMode::integer);
    check(near(integer.scale, 2) && near(integer.frame.width, 640));
    const auto tiny = calculateViewport({0, 0, 31, 17}, 320, 240, ScaleMode::integer);
    check(tiny.valid() && near(tiny.frame.width / tiny.frame.height, 4.0 / 3.0));
    check(!calculateViewport({0, 0, 0, 40}, 320, 240).valid());
    check(!calculateViewport({0, 0, 300, 400}, std::numeric_limits<double>::quiet_NaN(), 240).valid());

    ScreenManager dual;
    dual.screens = libretroScreens("skyemu", 256, 384);
    dual.layout = Layout::horizontal;
    auto sideBySide = dual.place({0, 0, 900, 450});
    check(sideBySide.size() == 2 && sideBySide[0].frame.x < sideBySide[1].frame.x);
    const auto touchBeforeSwap = ScreenManager::hitTest(
        {sideBySide[1].frame.x + sideBySide[1].frame.width / 2,
         sideBySide[1].frame.y + sideBySide[1].frame.height / 2}, sideBySide);
    check(touchBeforeSwap.pressed && touchBeforeSwap.screenID == "secondary");
    dual.layout = Layout::horizontalReverse;
    auto swapped = dual.place({0, 0, 900, 450});
    check(swapped.size() == 2 && swapped[0].screen.id == "secondary");
    const auto touchAfterSwap = ScreenManager::hitTest(
        {swapped[0].frame.x + swapped[0].frame.width / 2,
         swapped[0].frame.y + swapped[0].frame.height / 2}, swapped);
    check(touchAfterSwap.pressed && touchAfterSwap.screenID == "secondary" &&
          near(touchAfterSwap.local.x, 0.5) && near(touchAfterSwap.local.y, 0.5));
    dual.layout = Layout::primaryFocus;
    auto focused = dual.place({0, 0, 900, 450});
    check(focused.size() == 2 && focused[0].frame.width > focused[1].frame.width);
    dual.layout = Layout::secondaryFocus;
    focused = dual.place({0, 0, 900, 450});
    check(focused.size() == 2 && focused[0].screen.touch &&
          ScreenManager::hitTest({focused[0].frame.x + focused[0].frame.width / 2,
                                  focused[0].frame.y + focused[0].frame.height / 2}, focused).pressed);

    InputState input;
    check(!input.pressed(0));
    input.set(InputSource::virtualPad, 0, true);
    input.set(InputSource::controller, 0, true);
    input.set(InputSource::virtualPad, 0, false);
    check(input.pressed(0));
    input.release(InputSource::controller);
    check(!input.pressed(0));
    input.set(InputSource::remote, 15, true);
    input.set(InputSource::keyboard, 1, true);
    check(input.pressed(15) && input.pressed(1));
    input.set(InputSource::count, 0, true);
    input.set(InputSource::controller, 16, true);
    check(!input.pressed(0) && !input.pressed(16));
    input.clear();
    for (unsigned i = 0; i < 16; ++i) check(!input.pressed(i));
    input.setAxis(InputSource::controller, 0, 0, 2);
    check(input.analog(0, 0) == 32767);
    input.setAxis(InputSource::virtualPad, 0, 0, -0.5);
    input.release(InputSource::controller);
    check(input.analog(0, 0) == -16384);
    input.setAxis(InputSource::controller, 1, 1, -2);
    check(input.analog(1, 1) == -32767);
    input.setAxis(InputSource::controller, 1, 1, std::numeric_limits<double>::quiet_NaN());
    check(input.analog(1, 1) == 0);
    input.setAxis(InputSource::count, 0, 0, 1);
    check(input.analog(2, 0) == 0 && input.analog(0, 2) == 0);
    input.clear();
    check(input.analog(0, 0) == 0);
    auto center = virtualStick(3, 2, 100);
    check(near(center.x, 0) && near(center.y, 0));
    auto partial = virtualStick(50, 0, 100);
    check(partial.x > 0.4 && partial.x < 0.5 && near(partial.y, 0));
    auto diagonal = virtualStick(100, -100, 100);
    check(near(std::hypot(diagonal.x, diagonal.y), 1));
    check(diagonal.x > 0 && diagonal.y < 0);
    check(near(virtualStick(0, 1, 0).y, 0));
    check(near(virtualStick(std::numeric_limits<double>::quiet_NaN(), 0, 100).x, 0));
    for (const char *system : {"gb", "gbc", "gba", "nds", "neogeo", "sms", "gg", "nes", "pce", "sfc",
                               "ws", "wsc", "n64", "md", "segacd", "32x", "psx", "psp", "dreamcast",
                               "saturn", "arcade", "atari2600", "3ds", "gamecube", "ps2"}) {
        check(virtualControlProfile(system).has_value());
    }
    check(!virtualControlProfile("unknown-system").has_value());
    check(virtualControlProfile("n64")->leftStick && virtualControlProfile("3ds")->rightStick);
    check(virtualControlProfile("gba")->face == VirtualFace::two);
    check(dpadDirections(0, 0, 100) == 0);
    check(dpadDirections(100, 0, 100) == right);
    check(dpadDirections(-100, 0, 100) == left);
    check(dpadDirections(100, -100, 100) == (right | up));
    check(dpadDirections(0, 100, 100) == down);
    check(dpadDirections(0, 0, 0) == 0);
    const auto cRightUp = n64CButtons(cRight | cUp);
    check(near(cRightUp.x, -1) && near(cRightUp.y, -1));
    const auto opposing = n64CButtons(cLeft | cRight | cUp | cDown);
    check(near(opposing.x, 0) && near(opposing.y, 0));
    input.setAxis(InputSource::virtualPad, 0, 0, partial.x);
    input.setAxis(InputSource::virtualPad, 0, 1, diagonal.y);
    check(input.analog(0, 0) > 0 && input.analog(0, 1) < 0);
    std::cout << "BRUM screen/input: " << checks << " checks passed\n";
}
