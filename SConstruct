env = Environment(
    tools = ['default', 'nasm'],
    CCFLAGS = [
        '-Wall', '-Werror',
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
