#pragma once

#ifndef DETECTION_H
#define DETECTION_H

#include <QRect>
#include <QString>

struct Detection {
    int classId = -1;
    QRect rect;
    QString label;
    float score;
    int origW = 0;
    int origH = 0;
};

#endif // DETECTION_H
