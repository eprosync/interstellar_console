#include <filesystem>
#include <iostream>
#include <fstream>
#include <string>
#include <mutex>


#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

#include "interstellar/interstellar.hpp"
#include "interstellar/interstellar_signal.hpp"
#include "interstellar/interstellar_fs.hpp"
#include "interstellar/interstellar_memory.hpp"
#include "interstellar/interstellar_lxz.hpp"
#include "interstellar/interstellar_iot.hpp"
#include "interstellar/interstellar_sodium.hpp"

std::unique_ptr<std::mutex> mtx;
std::vector<std::string>& get_queue()
{
    static std::vector<std::string> queue = std::vector<std::string>();
    return queue;
}

extern "C" {
    EXPORT int main(int argc, char** argv) {
        int errs = Interstellar::init("");
        if (errs > 0) {
            std::cout << "Failed to initialize program: " << errs << std::endl;
            std::cout << "Press Enter to exit...";
            std::cin.get();
            return 0;
        }

        Interstellar::FS::api(Interstellar::FS::pwd());
        Interstellar::Memory::api();
        Interstellar::LXZ::api();
        Interstellar::IOT::api();
        Interstellar::Sodium::api();

        {
            using namespace Interstellar;

            Signal::add_error("entry_point", [](API::lua_State* L, std::string name, std::string identity, std::string error) {
                std::string state_name = Tracker::get_name(L);
                std::cout << "[" << state_name << "] [signal." << name << "." << identity << "] " << error << std::endl;
            });

            Reflection::Task::add_error("entry_point", [](API::lua_State* L, std::string error) {
                std::string state_name = Tracker::get_name(L);
                std::cout << "[" << state_name << "] [task] " << error << std::endl;
            });

            FS::add_error("entry_point", [](API::lua_State* L, std::string error) {
                std::string state_name = Tracker::get_name(L);
                std::cout << "[" << state_name << "] [fs] " << error << std::endl;
            });

            LXZ::add_error("entry_point", [](API::lua_State* L, std::string error) {
                std::string state_name = Tracker::get_name(L);
                std::cout << "[" << state_name << "] [lxz] " << error << std::endl;
            });

            IOT::add_error("entry_point", [](API::lua_State* L, std::string type, std::string error) {
                std::string state_name = Tracker::get_name(L);
                std::cout << "[" << state_name << "] [iot." << type << "] " << error << std::endl;
            });
        }

        std::cout << "Interstellar - ";

        #if defined(_WIN32)
                std::cout << "Windows ";
        #elif defined(__linux__)
                std::cout << "Linux ";
        #endif

        #if defined(__x86_64__) || defined(_M_X64)
                std::cout << "x64 ";
        #elif defined(__i386__) || defined(_M_IX86)
                std::cout << "x86 ";
        #endif

        std::cout << "- " __TIME__ " " __DATE__ << " - " << LUAJIT_VERSION << std::endl;
        std::cout << "Ctrl+C or 'exit' or 'quit' to escape this program." << std::endl;

        auto L = Interstellar::Reflection::open("main", true, false);

        for (int i = 1; i < argc; ++i) {
            std::string arg = argv[i];

            if (arg == "-f" && i + 1 < argc) {
                std::string filename = argv[++i];
                std::ifstream file(filename);
                if (!file) {
                    std::cerr << "ERROR - Could not open file \"" << filename << "\"" << std::endl;
                    return 1;
                }

                std::string line;
                std::stringstream data;
                while (std::getline(file, line)) {
                    data << line << std::endl;
                }

                std::string err = Interstellar::Reflection::execute(L, data.str(), "@" + filename);
                if (err.size() > 0) {
                    std::cout << "ERROR - " << err << std::endl;
                }

                break;
            }
            else if (arg == "-e" && i + 1 < argc) {
                std::stringstream s;
                for (++i; i < argc; ++i) {
                    s << argv[i];
                    if (i < argc - 1) s << " ";
                }
                s.str();

                std::string err = Interstellar::Reflection::execute(L, s.str(), "@internal");
                if (err.size() > 0) {
                    std::cout << "ERROR - " << err << std::endl;
                }

                break;
            }
        }

        mtx = std::make_unique<std::mutex>();

        std::thread([]() {
            std::string input;

            while (true) {
                std::getline(std::cin, input);
                std::cout << "> " << input << std::endl;
                std::lock_guard<std::mutex> guard(*mtx);
                auto& queue = get_queue();
                queue.push_back(input);
                if (input == "exit" || input == "quit") {
                    break;
                }
            }
        }).detach();

        while (true) {
            Interstellar::runtime();

            std::unique_lock<std::mutex> guard(*mtx);
            auto& queue = get_queue();
            if (queue.size() > 0) {
                for (auto input : queue) {
                    if (input == "exit" || input == "quit") {
                        Interstellar::Reflection::close(L);
                        return 0;
                    }

                    auto it = std::find(queue.begin(), queue.end(), input);
                    if (it != queue.end()) queue.erase(it);

                    guard.unlock();
                    std::string err = Interstellar::Reflection::execute(L, input, "@internal");
                    if (err.size() > 0) {
                        std::cout << "ERROR - " << err << std::endl;
                    }
                    guard.lock();
                }
            }
            guard.unlock();
        }

        return 0;
    }
}