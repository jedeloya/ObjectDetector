#ifndef CAMERALISTMODEL_H
#define CAMERALISTMODEL_H

#include <QAbstractListModel>

class CameraListModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IndexRole
    };

    explicit CameraListModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    struct CameraInfo { QString name; int index; };
    QVector<CameraInfo> m_cameras;
};

#endif // CAMERALISTMODEL_H
