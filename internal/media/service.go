// internal/media/service.go
package media

import (
	"context"
	"fmt"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"gorm.io/gorm"
)

type Service struct {
	client     *minio.Client
	bucketName string
	db         *gorm.DB // 🆕 Pridaj DB connection
}

func NewService(endpoint, accessKey, secretKey, bucketName string, db *gorm.DB) (*Service, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: true,
	})
	if err != nil {
		return nil, err
	}
	return &Service{
		client:     client,
		bucketName: bucketName,
		db:         db, // 🆕
	}, nil
}

func (s *Service) GetObject(ctx context.Context, objectName string) (*minio.Object, error) {
	return s.client.GetObject(ctx, s.bucketName, objectName, minio.GetObjectOptions{})
}

// 🆕 User ownership validation
func (s *Service) UserOwnsArtifact(userID interface{}, artifactType string) bool {
	var count int64
	err := s.db.Table("inventory_items").
		Where("user_id = ? AND item_type = 'artifact' AND deleted_at IS NULL", userID).
		Where("properties->>'type' = ?", artifactType).
		Count(&count)

	if err != nil {
		fmt.Printf("❌ Error checking artifact ownership: %v\n", err)
		return false
	}

	return count > 0
}
