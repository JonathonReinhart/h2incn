env = Environment(
    tools = ['default', 'nasm'],
    CCFLAGS = [
        '-Wall', '-Werror',
        '-Wstrict-prototypes', '-Wmissing-prototypes',
        '-Wmissing-declarations',
    ],
    ASFLAGS = [
        '-f', 'elf64',
    ],
    LINKFLAGS = [
        '-no-pie',
    ],
)

env.Program(
    target = 'h2incn',
    source = [
        'h2incn.c',
        'hashmap.c',
        'bintree.asm',
    ],
)
