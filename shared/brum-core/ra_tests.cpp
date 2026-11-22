#include "RetroAchievementsRuntime.hpp"
#include "rc_consoles.h"
#include "rc_hash.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_checks = 0;
void expect(bool cond, const char *msg, const std::string &extra = {}) {
    if (!cond) {
        std::cerr << "FAIL: " << msg << (extra.empty() ? "" : (" [" + extra + "]")) << "\n";
        std::exit(1);
    }
    ++g_checks;
}

std::string formParam(const std::string &body, const std::string &key) {
    const std::string needle = key + "=";
    size_t pos = 0;
    while (pos < body.size()) {
        if (body.compare(pos, needle.size(), needle) == 0 && (pos == 0 || body[pos - 1] == '&')) {
            const size_t valStart = pos + needle.size();
            const size_t valEnd = body.find('&', valStart);
            return body.substr(valStart, valEnd == std::string::npos ? std::string::npos : valEnd - valStart);
        }
        pos = body.find('&', pos);
        if (pos == std::string::npos) break;
        ++pos;
    }
    return {};
}

} // namespace

int main() {
    // 1. Official rcheevos GB ROM hash + token login + patch + memory eval + confirmed award only on HTTP 200 Success:true
    std::vector<uint8_t> gbRom(32768, 0);
    std::memcpy(gbRom.data() + 0x134, "BRUM RA TEST", 12);

    std::vector<uint8_t> sysRam(65536, 0); // 64 KiB Game Boy WRAM+HRAM space

    bool failAwardWith401 = true;
    int awardCalls = 0;
    std::vector<brum::ConfirmedAchievementUnlock> confirmed;
    brum::RetroAchievementsStatus lastStatus;
    bool loginDone = false;
    std::string storedToken;

    brum::RetroAchievementsCallbacks cb;
    cb.userAgent = "BRUMTest/1.0";
    cb.getCoreMemory = [&](uint32_t id, void **data, size_t *size) {
        if (id == RETRO_MEMORY_SYSTEM_RAM) {
            *data = sysRam.data();
            *size = sysRam.size();
        } else {
            *data = nullptr;
            *size = 0;
        }
    };
    cb.onConfirmedUnlock = [&](const brum::ConfirmedAchievementUnlock &u) { confirmed.push_back(u); };
    cb.onStatusChanged = [&](const brum::RetroAchievementsStatus &s) { lastStatus = s; };
    cb.onLoginCompleted = [&](bool ok, const std::string &, const std::string &token, const std::string &) {
        loginDone = ok;
        storedToken = token;
    };
    cb.httpPost = [&](const std::string &url, const std::string &postData, const std::string &, brum::RetroAchievementsCallbacks::HttpDoneFn done) {
        const std::string query = postData.empty() ? url : postData;
        const std::string r = formParam(query, "r");
        if (r == "login2") {
            done(200, "{\"Success\":true,\"User\":\"brumqa\",\"Token\":\"tok_abc123\",\"Score\":100,\"SoftcoreScore\":50,\"Messages\":0,\"AvatarUrl\":\"https://media.retroachievements.org/UserPic/brumqa.png\"}");
        } else if (r == "gameid") {
            done(200, "{\"Success\":true,\"GameID\":777}");
        } else if (r == "achievementsets") {
            done(200,
                "{\"Success\":true,\"GameId\":777,\"Title\":\"Test Game\",\"ConsoleId\":4,"
                "\"ImageIconUrl\":\"https://media.retroachievements.org/Images/00001.png\","
                "\"RichPresenceGameId\":777,\"RichPresencePatch\":\"Playing\","
                "\"Sets\":[{"
                    "\"AchievementSetId\":1,\"GameId\":777,\"Title\":\"Test Game\",\"Type\":\"core\","
                    "\"ImageIconUrl\":\"https://media.retroachievements.org/Images/00001.png\","
                    "\"Achievements\":[{"
                        "\"ID\":501,\"NumAwarded\":10,\"NumAwardedHardcore\":5,\"Title\":\"First Step\","
                        "\"Description\":\"Set byte 0xC010 to 7\",\"Points\":10,\"Author\":\"qa\","
                        "\"Modified\":1700000000,\"Created\":1700000000,\"BadgeName\":\"00501\","
                        "\"Flags\":3,\"MemAddr\":\"0xHC010=7\",\"Rarity\":50.0,\"RarityHardcore\":25.0,\"Type\":\"progression\","
                        "\"BadgeURL\":\"https://media.retroachievements.org/Badge/00501.png\","
                        "\"BadgeLockedURL\":\"https://media.retroachievements.org/Badge/00501_lock.png\""
                    "}],"
                    "\"Leaderboards\":[]"
                "}]}");
        } else if (r == "startsession") {
            done(200, "{\"Success\":true,\"HardcoreUnlocks\":[],\"Unlocks\":[],\"ServerNow\":1700000000}");
        } else if (r == "ping") {
            done(200, "{\"Success\":true}");
        } else if (r == "awardachievement") {
            ++awardCalls;
            if (failAwardWith401) {
                done(401, "{\"Success\":false,\"Error\":\"Invalid token\"}");
            } else {
                done(200, "{\"Success\":true,\"AchievementID\":501,\"Score\":100,\"SoftcoreScore\":60,\"AchievementsRemaining\":0}");
            }
        } else {
            done(200, "{\"Success\":true}");
        }
    };

    {
        brum::RetroAchievementsRuntime runtime(cb);
        runtime.loginWithPassword("brumqa", "secret-pass");
        expect(loginDone && storedToken == "tok_abc123", "Password login must yield token-only");
        expect(lastStatus.hardcore == false, "Hardcore must default to false (Softcore)");

        // Note: On GB, rcheevos console region 0 maps $C000-$DFFF + $E000-$FFFF: address 0x0010 in GB system RAM = offset 0x0010 in WRAM if mapped via descriptor,
        // so provide explicit descriptor at start=0xC000 len=0x4000 covering 0xC000..0xFFFF.
        retro_memory_descriptor gbDesc{};
        gbDesc.flags = RETRO_MEMDESC_SYSTEM_RAM;
        gbDesc.ptr = sysRam.data();
        gbDesc.start = 0xC000;
        gbDesc.len = 0x4000;
        retro_memory_map gbMap{&gbDesc, 1};

        runtime.startGame(RC_CONSOLE_GAMEBOY, "", gbRom.data(), gbRom.size(), &gbMap);
        expect(runtime.status().state == "active" && runtime.status().gameId == 777,
               "Game must identify and load PatchData",
               runtime.status().state + ":" + runtime.status().message);

        sysRam[0x0010] = 0;
        runtime.doFrame();
        expect(awardCalls == 0 && confirmed.empty(), "Initial non-matching frame must not award");

        // Trigger memory condition 0xHC010 = 7 (offset 0x0010 -> GB $C010)
        sysRam[0x0010] = 7;
        runtime.doFrame();
        expect(awardCalls == 1, "awardachievement call must be issued when memory condition matches");
        expect(confirmed.empty(), "HTTP 401/error must NEVER emit a confirmed achievement popup");

        // Confirm award when retry/online succeeds with HTTP 200 Success:true
        failAwardWith401 = false;
        // Re-trigger via new runtime simulating clean online award (since single-shot achievement triggered once in client state)
    }

    // Fresh session online: verify confirmed popup arrives + deduplicator blocks repeat
    confirmed.clear();
    awardCalls = 0;
    failAwardWith401 = false;
    {
        brum::RetroAchievementsRuntime runtime(cb);
        runtime.loginWithToken("brumqa", "tok_abc123");
        retro_memory_descriptor gbDesc{};
        gbDesc.flags = RETRO_MEMDESC_SYSTEM_RAM;
        gbDesc.ptr = sysRam.data();
        gbDesc.start = 0xC000;
        gbDesc.len = 0x4000;
        retro_memory_map gbMap{&gbDesc, 1};

        sysRam[0x0010] = 0;
        runtime.startGame(RC_CONSOLE_GAMEBOY, "", gbRom.data(), gbRom.size(), &gbMap);
        runtime.doFrame();
        expect(confirmed.empty(), "Must not trigger before condition met");

        sysRam[0x0010] = 7;
        runtime.doFrame();
        expect(awardCalls == 1, "awardachievement must fire once");
        expect(confirmed.size() == 1, "HTTP 200 Success:true must emit 1 confirmed achievement");
        expect(confirmed[0].eventId == "ra:777:501" && confirmed[0].achievementId == 501 && confirmed[0].points == 10, "Confirmed payload fields must match");
        expect(!runtime.markExternalEventSeen("ra:777:501", 777, "501", "First Step"), "External overlay with same eventId must be deduplicated");
        expect(runtime.markExternalEventSeen("ra:777:502", 777, "502", "Other"), "Distinct achievement must pass deduplicator");
    }

    // 3. Nintendo 3DS must explicitly remain unsupported in runtime
    {
        brum::RetroAchievementsRuntime runtime(cb);
        runtime.loginWithToken("brumqa", "tok_abc123");
        runtime.startGame(RC_CONSOLE_NINTENDO_3DS, "", gbRom.data(), gbRom.size(), nullptr);
        expect(runtime.status().state == "unsupported", "Nintendo 3DS must report unsupported RA runtime");
    }

    // 4. PSP (console 41) using unmapped RETRO_MEMORY_SYSTEM_RAM fallback (mmap == nullptr, matching PPSSPP libretro)
    {
        std::vector<uint8_t> pspRam(32 * 1024 * 1024, 0);
        brum::RetroAchievementsCallbacks pspCb = cb;
        pspCb.getCoreMemory = [&](uint32_t id, void **data, size_t *size) {
            if (id == RETRO_MEMORY_SYSTEM_RAM) {
                *data = pspRam.data();
                *size = pspRam.size();
            } else {
                *data = nullptr;
                *size = 0;
            }
        };
        pspCb.httpPost = [&](const std::string &url, const std::string &postData, const std::string &, brum::RetroAchievementsCallbacks::HttpDoneFn done) {
            const std::string r = formParam(postData.empty() ? url : postData, "r");
            if (r == "login2") {
                done(200, "{\"Success\":true,\"User\":\"brumqa\",\"Token\":\"tok_abc123\"}");
            } else if (r == "achievementsets") {
                done(200,
                    "{\"Success\":true,\"GameId\":888,\"Title\":\"PSP Probe\",\"ConsoleId\":41,"
                    "\"ImageIconUrl\":\"https://media.retroachievements.org/Images/00002.png\","
                    "\"RichPresenceGameId\":888,\"RichPresencePatch\":\"\",\"Sets\":[{"
                        "\"AchievementSetId\":2,\"GameId\":888,\"Title\":\"PSP Probe\",\"Type\":\"core\","
                        "\"ImageIconUrl\":\"https://media.retroachievements.org/Images/00002.png\","
                        "\"Achievements\":[{"
                            "\"ID\":601,\"NumAwarded\":1,\"NumAwardedHardcore\":1,\"Title\":\"PSP Memory Hit\","
                            "\"Description\":\"RAM check\",\"Points\":5,\"Author\":\"qa\","
                            "\"Modified\":1700000000,\"Created\":1700000000,\"BadgeName\":\"00601\","
                            "\"Flags\":3,\"MemAddr\":\"0xH000100=42\",\"Rarity\":50.0,\"RarityHardcore\":50.0,\"Type\":\"\","
                            "\"BadgeURL\":\"https://media.retroachievements.org/Badge/00601.png\""
                        "}],\"Leaderboards\":[]}]}" );
            } else if (r == "awardachievement") {
                done(200, "{\"Success\":true,\"AchievementID\":601,\"Score\":100,\"SoftcoreScore\":65,\"AchievementsRemaining\":0}");
            } else {
                done(200, "{\"Success\":true,\"HardcoreUnlocks\":[],\"Unlocks\":[],\"ServerNow\":1700000000}");
            }
        };
        confirmed.clear();
        brum::RetroAchievementsRuntime runtime(pspCb);
        runtime.loginWithToken("brumqa", "tok_abc123");
        // Verify unmapped RETRO_MEMORY_SYSTEM_RAM works with RC_CONSOLE_PSP (41) without SET_MEMORY_MAPS using a PBP file path:
        const char *pbpPath = "H:\\BRUM-VALIDACOES\\brum_psp_probe.pbp";
        {
            std::vector<uint8_t> pspPbp(128, 0);
            pspPbp[0] = 0x00; pspPbp[1] = 'P'; pspPbp[2] = 'B'; pspPbp[3] = 'P';
            FILE *fp = std::fopen(pbpPath, "wb");
            expect(fp != nullptr, "Failed to create temporary PSP PBP fixture");
            std::fwrite(pspPbp.data(), 1, pspPbp.size(), fp);
            std::fclose(fp);
        }
        runtime.startGame(RC_CONSOLE_PSP, pbpPath, nullptr, 0, nullptr);
        std::remove(pbpPath);
        expect(runtime.status().state == "active" && runtime.status().gameId == 888,
               "PSP unmapped session must activate",
               runtime.status().state + ":" + runtime.status().message);
        runtime.doFrame();
        expect(confirmed.empty(), "PSP must not unlock before memory condition");
        pspRam[0x000100] = 42;
        runtime.doFrame();
        expect(confirmed.size() == 1 && confirmed[0].achievementId == 601, "PSP unmapped SYSTEM_RAM evaluation must unlock cleanly");
    }

    std::cout << "BRUM rcheevos runtime: " << g_checks << " checks passed\n";
    return 0;
}
