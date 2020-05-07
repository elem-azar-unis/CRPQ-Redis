//
// Created by admin on 2020/5/7.
//

#ifndef REDIS_4_0_8_LIST_BASICS_H
#define REDIS_4_0_8_LIST_BASICS_H

#include "server.h"

#define BASE (1<<24)
#define RDM_STEP 8
typedef struct position
{
    unsigned int pos;
    int pid;
    int count;
} position;

inline int pos_cmp(const position *p1, const position *p2)
{
    if (p1->pos != p2->pos) return p1->pos - p2->pos;
    if (p1->pid != p2->pid) return p1->pid - p2->pid;
    return p1->count - p2->count;
}

typedef struct list_element_identifier
{
    int num;
    position *p;
} leid;

inline void leidFree(leid *id)
{
    zfree(id->p);
    zfree(id);
}

sds leidToSds(const leid *p);

leid *sdsToLeid(sds s);

int leid_cmp(const leid *id1, const leid *id2);

inline int lprefix(leid *p, int i)
{
    if (p == NULL)return 0;
    if (i >= p->num)return 0;
    return p->p[i].pos;
}

inline int rprefix(leid *p, int i)
{
    if (p == NULL)return BASE;
    if (i >= p->num)return BASE;
    return p->p[i].pos;
}

leid *constructLeid(leid *p, leid *q, lc *t);

#endif //REDIS_4_0_8_LIST_BASICS_H
