/*
 * relay-client -- internal tool for talking to the Ferryman Relay
 * service. Ships to players as a compiled binary, intentionally, same
 * as the real internal tool would have. Protocol and auth token are
 * meant to be recovered by reversing this binary (strings/objdump are
 * enough -- this is "light" reverse engineering, not an unpacking
 * exercise).
 *
 * Usage: ./relay-client <host> <port> <COMMAND> [args...]
 *   e.g. ./relay-client relay 9099 VERSION
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>

#define MAGIC "FERRY1"
#define XOR_KEY 0x5A

/* Honeypot: a plain, unobfuscated string that LOOKS like it could be
 * the auth token (same shape, same prefix) and shows up immediately in
 * `strings`. It is not used anywhere in this program and the server
 * rejects it -- the real token below is XOR'd on purpose; this one
 * isn't, and that difference is the actual clue. */
static const char DECOY_TOKEN[] = "FR-0001-LEGACY";

/* The real auth token, XOR'd with XOR_KEY so it doesn't show up as a
 * plain string in `strings relay-client` -- it DOES show up as these
 * bytes, and the XOR routine below is visible with objdump -d. */
static unsigned char TOKEN_XORED[] = {
    0x1c, 0x08, 0x77, 0x63, 0x3c, 0x68, 0x39, 0x77, 0x08, 0x1f, 0x16, 0x1b, 0x03
};
#define TOKEN_LEN (sizeof(TOKEN_XORED))

static void decode_token(char *out) {
    for (size_t i = 0; i < TOKEN_LEN; i++) {
        out[i] = TOKEN_XORED[i] ^ XOR_KEY;
    }
    out[TOKEN_LEN] = '\0';
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s <host> <port> <COMMAND> [args...]\n", argv[0]);
        return 1;
    }
    const char *host = argv[1];
    const char *port = argv[2];
    const char *cmd = argv[3];

    char token[TOKEN_LEN + 1];
    decode_token(token);

    char frame[4096];
    if (strcmp(cmd, "VERSION") == 0) {
        snprintf(frame, sizeof(frame), "%s|VERSION\n", MAGIC);
    } else if (strcmp(cmd, "STATUS") == 0) {
        snprintf(frame, sizeof(frame), "%s|STATUS|%s\n", MAGIC, token);
    } else if (strcmp(cmd, "RUN") == 0 && argc >= 5) {
        snprintf(frame, sizeof(frame), "%s|RUN|%s|%s\n", MAGIC, token, argv[4]);
    } else {
        fprintf(stderr, "unknown command: %s\n", cmd);
        return 1;
    }

    struct addrinfo hints = {0}, *res;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo(host, port, &hints, &res) != 0) {
        fprintf(stderr, "resolve failed\n");
        return 1;
    }
    int fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (fd < 0 || connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
        fprintf(stderr, "connect failed\n");
        return 1;
    }
    write(fd, frame, strlen(frame));

    char buf[8192];
    ssize_t n;
    while ((n = read(fd, buf, sizeof(buf) - 1)) > 0) {
        buf[n] = '\0';
        fputs(buf, stdout);
    }
    close(fd);
    return 0;
}
