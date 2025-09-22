#include <iostream>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

int main() {
    std::cout << "External Library Example - GCC Toolchain Demo\n";
    std::cout << "==============================================\n\n";

    // Create a JSON object using the external library
    json person;
    person["name"] = "Alice Johnson";
    person["age"] = 28;
    person["city"] = "New York";
    person["hobbies"] = {"reading", "programming", "hiking"};
    person["is_student"] = false;
    person["gpa"] = nullptr; // Not a student, so no GPA

    std::cout << "Created JSON object using nlohmann/json library:\n";
    std::cout << person.dump(2) << "\n\n"; // Pretty print with 2-space indent

    // Demonstrate parsing from string
    std::string json_string = R"({
        "project": "Multi-GCC Toolchain",
        "languages": ["C", "C++"],
        "toolchains": {
            "fedora": {"version": "15.0.1", "isolated": true},
            "centos": {"version": "11.5.0", "isolated": true},
            "host": {"version": "15.2.1", "isolated": false}
        },
        "features": ["distribution-specific flags", "shared utilities", "host integration"]
    })";

    std::cout << "Parsing JSON string:\n";
    try {
        json project_info = json::parse(json_string);

        std::cout << "Project: " << project_info["project"] << "\n";
        std::cout << "Languages: ";
        for (const auto& lang : project_info["languages"]) {
            std::cout << lang << " ";
        }
        std::cout << "\n";

        std::cout << "Toolchains:\n";
        for (const auto& [name, info] : project_info["toolchains"].items()) {
            std::cout << "  " << name << ": version " << info["version"]
                      << " (isolated: " << (info["isolated"] ? "yes" : "no") << ")\n";
        }

        std::cout << "Features:\n";
        for (const auto& feature : project_info["features"]) {
            std::cout << "  - " << feature << "\n";
        }

    } catch (const json::exception& e) {
        std::cerr << "JSON parsing error: " << e.what() << "\n";
        return 1;
    }

    std::cout << "\nLibrary info:\n";
    std::cout << "nlohmann/json version: " << NLOHMANN_JSON_VERSION_MAJOR << "."
              << NLOHMANN_JSON_VERSION_MINOR << "." << NLOHMANN_JSON_VERSION_PATCH << "\n";
    std::cout << "Compiled with GCC version: " << __GNUC__ << "."
              << __GNUC_MINOR__ << "." << __GNUC_PATCHLEVEL__ << "\n";
    std::cout << "External library integrated successfully!\n";

    return 0;
}