#include <cstdint>
#include <fstream>
#include <iostream>
#include <filesystem>

/* https://en.cppreference.com/cpp/filesystem/exists */
namespace fs = std::filesystem;

int main() {
    fs::path dossier = "./tests";

    /* Vérifier si le dossier existe */
    if (fs::exists(dossier))
        std::cout << dossier << " existe\n";
    else
        std::cout << dossier << " n'existe pas\n";

    for (auto const& dir_entry : fs::directory_iterator{dossier}) 
        std::cout << dir_entry.path() << '\n';
    return 0;
}