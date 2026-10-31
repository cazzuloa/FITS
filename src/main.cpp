#include <array>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <filesystem>
#include <memory>
#include <sstream>
#include <string>
#include <stdexcept>

#include <openssl/evp.h>

using namespace std;

// Adapter de https://stackoverflow.com/a/40155962
// Modifié pour calculer le hash du contenu des fichiers par blocs.
string sha256(const filesystem::path& path) {
    ifstream file(path, ios::binary);
    if (!file) {
        throw runtime_error("Impossible d'ouvrir le fichier : " + path.string());
    }

    unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>
        context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!context) {
        throw runtime_error("Impossible de créer le contexte OpenSSL");
    }

    if (EVP_DigestInit_ex(context.get(), EVP_sha256(), nullptr) != 1) {
        throw runtime_error("Échec de l'initialisation SHA-256");
    }

    array<char, 64 * 1024> buffer{};
    while (true) {
        file.read(buffer.data(), static_cast<streamsize>(buffer.size()));
        const streamsize bytes_read = file.gcount();

        if (bytes_read > 0 &&
            EVP_DigestUpdate(context.get(), buffer.data(),
                             static_cast<size_t>(bytes_read)) != 1) {
            throw runtime_error("Échec du calcul SHA-256 pour : " + path.string());
        }

        if (file.bad()) {
            throw runtime_error("Erreur pendant la lecture du fichier : " + path.string());
        }
        if (file.eof()) {
            break;
        }
        if (file.fail()) {
            throw runtime_error("Erreur pendant la lecture du fichier : " + path.string());
        }
    }

    array<unsigned char, EVP_MAX_MD_SIZE> digest{};
    unsigned int digest_length = 0;
    if (EVP_DigestFinal_ex(context.get(), digest.data(), &digest_length) != 1) {
        throw runtime_error("Échec de la finalisation SHA-256");
    }

    ostringstream result;
    result << hex << setfill('0');
    for (unsigned int i = 0; i < digest_length; ++i) {
        result << setw(2) << static_cast<unsigned int>(digest[i]);
    }
    return result.str();
}

int main() {
    filesystem::path dossier = "./tests";

    try {
        if (!filesystem::is_directory(dossier)) {
            cerr << dossier << " n'est pas un dossier accessible\n";
            return 1;
        }

        for (const auto& dir_entry : filesystem::recursive_directory_iterator{dossier}) {
            if (dir_entry.is_regular_file()) {
                cout << dir_entry.path() << " : " << sha256(dir_entry.path()) << '\n';
            }
        }
    } catch (const filesystem::filesystem_error& error) {
        cerr << "Erreur filesystem : " << error.what() << '\n';
        return 1;
    } catch (const runtime_error& error) {
        cerr << "Erreur : " << error.what() << '\n';
        return 1;
    }

    return 0;
}