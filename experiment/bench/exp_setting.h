//
// Created by admin on 2020/4/15.
//

#ifndef BENCH_EXP_SETTING_H
#define BENCH_EXP_SETTING_H

class exp_setting
{
private:
    static inline void set_default()
    {
        delay = 50;
        delay_low = 10;
        total_clusters = 3;
        server_per_cluster = 3;
        total_ops = 20000000;
        op_per_sec = 10000;
    }

public:
    static int delay;
    static int delay_low;
    static int total_clusters;
    static int server_per_cluster;
    static int total_ops;
    static int op_per_sec;

    static enum exp_type
    {
        e_speed = 0, e_replica = 1, e_delay = 2, e_pattern
    } type;
    static const char *type_str[3];
    static const char *pattern_name;
    static int round_num;


    static inline void set_speed(int round, int speed)
    {
        set_default();
        op_per_sec = speed;
        total_ops = 200000;
        round_num = round;
        type = e_speed;
    }

    static inline void set_replica(int round, int cluster, int serverPCluster)
    {
        set_default();
        total_clusters = cluster;
        server_per_cluster = serverPCluster;
        total_ops = 20000000;
        round_num = round;
        type = e_replica;
    }

    static inline void set_delay(int round, int hd, int ld)
    {
        set_default();
        delay = hd;
        delay_low = ld;
        total_ops = 10000000;
        round_num = round;
        type = e_delay;
    }

    static inline void set_pattern(const char *name)
    {
        set_default();
        pattern_name = name;
        type = e_pattern;
    }
};

#endif //BENCH_EXP_SETTING_H