import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('posts')
export class PostEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'author_id' })
  authorId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author!: UserEntity;

  @Column({ type: 'text', default: '' })
  caption!: string;

  @Column({ name: 'image_urls', type: 'jsonb', default: () => "'[]'" })
  imageUrls!: string[]; // Lưu tối đa 5 URL từ Cloudinary

  @OneToMany(() => PostCommentEntity, (cmt) => cmt.post)
  comments?: PostCommentEntity[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

@Entity('post_comments')
export class PostCommentEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'post_id' })
  postId!: string;

  @ManyToOne(() => PostEntity, (post) => post.comments, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'post_id' })
  post!: PostEntity;

  @Column({ name: 'author_id' })
  authorId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author!: UserEntity;

  @Column({ type: 'text' })
  content!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

