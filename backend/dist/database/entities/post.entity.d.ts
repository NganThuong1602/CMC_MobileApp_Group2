import { UserEntity } from './user.entity';
export declare class PostEntity {
    id: string;
    authorId: string;
    author: UserEntity;
    caption: string;
    imageUrls: string[];
    comments?: PostCommentEntity[];
    createdAt: Date;
}
export declare class PostCommentEntity {
    id: string;
    postId: string;
    post: PostEntity;
    authorId: string;
    author: UserEntity;
    content: string;
    createdAt: Date;
}
