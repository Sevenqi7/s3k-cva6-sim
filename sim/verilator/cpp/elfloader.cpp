#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <elf.h>
#include <fcntl.h>
#include <map>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <type_traits>
#include <unistd.h>
#include <utility>
#include <vector>

namespace
{

std::vector<std::pair<uint64_t, uint64_t>> sections;
std::map<uint64_t, std::vector<uint8_t>> mems;
std::map<std::string, uint64_t> symbols;
int section_index = 0;

template <typename ShdrT, typename SymT>
void load_symbols(const uint8_t *image, size_t size, const ShdrT *shdrs, uint16_t shnum)
{
    for (uint16_t i = 0; i < shnum; ++i) {
        const auto &shdr = shdrs[i];
        if ((shdr.sh_type != SHT_SYMTAB && shdr.sh_type != SHT_DYNSYM) || shdr.sh_entsize == 0 || shdr.sh_size == 0) {
            continue;
        }
        if (shdr.sh_link >= shnum) {
            continue;
        }

        const auto &strtab = shdrs[shdr.sh_link];
        if (size < shdr.sh_offset + shdr.sh_size || size < strtab.sh_offset + strtab.sh_size) {
            continue;
        }

        const auto *symtab = reinterpret_cast<const SymT *>(image + shdr.sh_offset);
        const auto *strbase = reinterpret_cast<const char *>(image + strtab.sh_offset);
        const size_t num_syms = shdr.sh_size / sizeof(SymT);

        for (size_t sym_idx = 0; sym_idx < num_syms; ++sym_idx) {
            const auto &sym = symtab[sym_idx];
            if (sym.st_name >= strtab.sh_size || sym.st_value == 0) {
                continue;
            }

            const char *name = strbase + sym.st_name;
            if (*name == '\0') {
                continue;
            }

            symbols[std::string(name)] = static_cast<uint64_t>(sym.st_value);
        }
    }
}

template <typename EhdrT, typename PhdrT> bool load_elf_image(const uint8_t *image, size_t size)
{
    const auto *ehdr = reinterpret_cast<const EhdrT *>(image);
    if (size < ehdr->e_phoff + (ehdr->e_phnum * sizeof(PhdrT))) {
        std::fprintf(stderr, "[elfloader] malformed ELF headers\n");
        return false;
    }

    const auto *phdrs = reinterpret_cast<const PhdrT *>(image + ehdr->e_phoff);
    for (uint16_t i = 0; i < ehdr->e_phnum; ++i) {
        const auto &phdr = phdrs[i];
        if (phdr.p_type != PT_LOAD || phdr.p_memsz == 0) {
            continue;
        }
        if (size < phdr.p_offset + phdr.p_filesz) {
            std::fprintf(stderr, "[elfloader] truncated PT_LOAD segment\n");
            return false;
        }

        std::vector<uint8_t> data(phdr.p_memsz, 0);
        if (phdr.p_filesz != 0) {
            std::memcpy(data.data(), image + phdr.p_offset, phdr.p_filesz);
        }

        const uint64_t base = static_cast<uint64_t>(phdr.p_paddr);
        sections.push_back({base, static_cast<uint64_t>(data.size())});
        mems[base] = std::move(data);
    }

    if (ehdr->e_shoff != 0 && ehdr->e_shnum != 0 && size >= ehdr->e_shoff + (ehdr->e_shnum * ehdr->e_shentsize)) {
        const auto *shdrs = reinterpret_cast<
            const typename std::conditional<sizeof(EhdrT) == sizeof(Elf64_Ehdr), Elf64_Shdr, Elf32_Shdr>::type *>(
            image + ehdr->e_shoff);
        if constexpr (sizeof(EhdrT) == sizeof(Elf64_Ehdr)) {
            load_symbols<Elf64_Shdr, Elf64_Sym>(image, size, shdrs, ehdr->e_shnum);
        } else {
            load_symbols<Elf32_Shdr, Elf32_Sym>(image, size, shdrs, ehdr->e_shnum);
        }
    }

    return true;
}

} // namespace

extern "C" int read_elf(const char *filename)
{
    const int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        std::perror("[elfloader] open");
        return -1;
    }

    struct stat st;
    if (fstat(fd, &st) != 0) {
        std::perror("[elfloader] fstat");
        close(fd);
        return -1;
    }

    if (st.st_size < static_cast<off_t>(sizeof(Elf64_Ehdr))) {
        std::fprintf(stderr, "[elfloader] file too small: %s\n", filename);
        close(fd);
        return -1;
    }

    void *mapped = mmap(nullptr, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (mapped == MAP_FAILED) {
        std::perror("[elfloader] mmap");
        return -1;
    }

    const auto *image = reinterpret_cast<const uint8_t *>(mapped);
    bool ok = false;
    if (image[EI_MAG0] == ELFMAG0 && image[EI_MAG1] == ELFMAG1 && image[EI_MAG2] == ELFMAG2
        && image[EI_MAG3] == ELFMAG3) {
        if (image[EI_CLASS] == ELFCLASS64) {
            ok = load_elf_image<Elf64_Ehdr, Elf64_Phdr>(image, st.st_size);
        } else if (image[EI_CLASS] == ELFCLASS32) {
            ok = load_elf_image<Elf32_Ehdr, Elf32_Phdr>(image, st.st_size);
        } else {
            std::fprintf(stderr, "[elfloader] unsupported ELF class in %s\n", filename);
        }
    } else {
        std::fprintf(stderr, "[elfloader] invalid ELF magic in %s\n", filename);
    }

    munmap(mapped, st.st_size);
    return ok ? 0 : -1;
}

extern "C" int get_section(unsigned long long *address, unsigned long long *len)
{
    if (section_index >= static_cast<int>(sections.size())) {
        return 0;
    }

    *address = static_cast<unsigned long long>(sections[section_index].first);
    *len = static_cast<unsigned long long>(sections[section_index].second);
    ++section_index;
    return 1;
}

extern "C" unsigned long long read_section_word(unsigned long long address, unsigned int word_index)
{
    auto it = mems.find(static_cast<uint64_t>(address));
    if (it == mems.end()) {
        std::fprintf(stderr, "[elfloader] missing section for address 0x%llx\n", address);
        return 0;
    }

    const size_t offset = static_cast<size_t>(word_index) * sizeof(uint64_t);
    if (offset >= it->second.size()) {
        return 0;
    }

    uint64_t word = 0;
    const size_t copy_size = std::min(sizeof(word), it->second.size() - offset);
    std::memcpy(&word, it->second.data() + offset, copy_size);
    return static_cast<unsigned long long>(word);
}

extern "C" int get_symbol(const char *name, unsigned long long *address)
{
    auto it = symbols.find(name);
    if (it == symbols.end()) {
        return 0;
    }

    *address = static_cast<unsigned long long>(it->second);
    return 1;
}
