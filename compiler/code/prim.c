
# include <stdint.h>
#define V 8
#define inf 32767

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

    #include <stdio.h>
    int CPU_DONE = 0, OUT = 0;

    void PrintMST(int T[][V-2], int G[V][V]){
        printf("\nMinimum Spanning Tree Edges (w/ cost)\n");
        int sum = 0;
        for (int i = 0; i<V-2; i++){
            int c = G[T[0][i]][T[1][i]];
            printf("[%d]---[%d] cost: %d\n", T[0][i], T[1][i], c);
            sum += c;
        }
        printf("\nTotal cost of MST: %d\n", sum);
    }

#else  // for the test device
    #define OUT                 (* (volatile    int * ) 0x00001004)
    #define CPU_DONE            (* (volatile int8_t * ) 0x00001008)

    void PrintMST(int T[][V-2], int G[V][V]) {
        int sum = 0;
        for (int i = 0; i<V-2; i++){
            int c = G[T[0][i]][T[1][i]];
            OUT = T[0][i]; OUT = T[1][i]; OUT = c;
            sum += c;
        }
        OUT = sum;
    }
    // generate local bss
    void *memset(void *dst, int val, unsigned int n) {
        unsigned char *p = (unsigned char *)dst;
        for (unsigned int i = 0; i < n; i++) {
            p[i] = (unsigned char)val;
        }
        return dst;
    }

    void *memcpy(void *dst, const void *src, unsigned int n) {
        unsigned char *d = (unsigned char *)dst;
        const unsigned char *s = (const unsigned char *)src;
        for (unsigned int i = 0; i < n; i++) {
            d[i] = s[i];
        }
        return dst;
    }
#endif

void PrimsMST(int G[V][V], int n){
    int u;
    int v;
    int min = {inf};
    int track[V];
    int T[2][V-2] = {0};

    // Initial: Find min cost edge
    for (int i = 1; i<V; i++){
        track[i] = inf;  // Initialize track array with INFINITY
        for (int j = i; j<V; j++){
            if (G[i][j] < min){
                min = G[i][j];
                u = i;
                v = j;
            }
        }
    }
    T[0][0] = u;
    T[1][0] = v;
    track[u] = track[v] = 0;

    // Initialize track array to track min cost edges
    for (int i=1; i<V; i++){
        if (track[i] != 0){
            if (G[i][u] < G[i][v]){
                track[i] = u;
            } else {
                track[i] = v;
            }
        }
    }

    // Repeat
    for (int i=1; i<n-1; i++){
        int k;
        min = inf;
        for (int j=1; j<V; j++){
            if (track[j] != 0 && G[j][track[j]] < min){
                k = j;
                min = G[j][track[j]];
            }
        }
        T[0][i] = k;
        T[1][i] = track[k];
        track[k] = 0;

        // Update track array to track min cost edges
        for (int j=1; j<V; j++){
            if (track[j] != 0 && G[j][k] < G[j][track[j]]){
                track[j] = k;
            }
        }
    }
    PrintMST(T, G);
}

int main() {

    OUT = 0; CPU_DONE = 1;
    int cost [V][V] = {
            {inf, inf, inf, inf, inf, inf, inf, inf},
            {inf, inf, 25, inf, inf, inf, 5, inf},
            {inf, 25, inf, 12, inf, inf, inf, 10},
            {inf, inf, 12, inf, 8, inf, inf, inf},
            {inf, inf, inf, 8, inf, 16, inf, 14},
            {inf, inf, inf, inf, 16, inf, 20, 18},
            {inf, 5, inf, inf, inf, 20, inf, inf},
            {inf, inf, 10, inf, 14, 18, inf, inf},
    };

    int n = sizeof(cost[0])/sizeof(cost[0][0]) - 1;

    PrimsMST(cost, n);
    CPU_DONE = 1;
    return 0;
}
