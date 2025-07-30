// internal/media/service.go
package media

import (
	"context"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Service struct {
	client     *minio.Client
	bucketName string
}

func NewService(endpoint, accessKey, secretKey, bucketName string) (*Service, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: true,
	})
	if err != nil {
		return nil, err
	}
	return &Service{client: client, bucketName: bucketName}, nil
}

func (s *Service) GetObject(ctx context.Context, objectName string) (*minio.Object, error) {
	return s.client.GetObject(ctx, s.bucketName, objectName, minio.GetObjectOptions{})
}
