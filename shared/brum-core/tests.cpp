#include "ScreenManager.hpp"
#include "InputState.hpp"
#include "N64Input.hpp"
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
        for (unsigned layout = 0; layout < 6; ++layout) {
            manager.layout = static_cast<Layout>(layout);
            for (unsigned rotation = 0; rotation < 4; ++rotation) {
                manager.quarterTurns = rotation;
                for (double scale : {0.25, 0.75, 1.0}) {
                    manager.scale = scale;
                    const Rect viewport {31, 57, 900, 600};
                    auto placements = manager.place(viewport);
                    check(placements.size() == (layout >= 4 ? 1u : 2u));
                    check(placements.front().screen.id == (layout == 1 || layout == 3 || layout == 5 ? "secondary" : "primary"));
                    for (const auto& p : placements) {
                        check(viewport.contains({p.frame.x, p.frame.y}));
                        check(viewport.contains({p.frame.x + p.frame.width, p.frame.y + p.frame.height}));
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
    const auto cRightUp = n64CButtons(cRight | cUp);
    check(near(cRightUp.x, -1) && near(cRightUp.y, -1));
    const auto opposing = n64CButtons(cLeft | cRight | cUp | cDown);
    check(near(opposing.x, 0) && near(opposing.y, 0));
    input.setAxis(InputSource::virtualPad, 0, 0, partial.x);
    input.setAxis(InputSource::virtualPad, 0, 1, diagonal.y);
    check(input.analog(0, 0) > 0 && input.analog(0, 1) < 0);
    std::cout << "BRUM screen/input: " << checks << " checks passed\n";
}
