#include "cameralistmodel.h"

#include <QCameraDevice>
#include <QMediaDevices>

CameraListModel::CameraListModel(QObject *parent)
    : QAbstractListModel{parent}
{
    const auto devices = QMediaDevices::videoInputs();
    int idx = 0;

    for (const QCameraDevice &dev : devices) {
        m_cameras.append({ dev.description(), idx });
        idx++;
    }
}

int CameraListModel::rowCount(const QModelIndex &) const {
    return m_cameras.size();
}

QVariant CameraListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_cameras.size())
        return {};

    const auto &c = m_cameras[index.row()];

    switch (role) {
    case NameRole: return c.name;
    case IndexRole: return c.index;
    default: return {};
    }
}

QHash<int, QByteArray> CameraListModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {IndexRole, "index"}
    };
}
