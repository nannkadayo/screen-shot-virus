const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Expressアプリケーションの作成
const app = express();
const port = 8000;

// アップロードディレクトリを定義
const UPLOAD_DIR = './uploads';
const DOWNLOAD_DIR = './download';
const MAX_FILES = 2; // ファイル数の上限

// multerの設定：ファイルの保存先とファイル名の設定
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        // ディレクトリが存在しない場合、作成
        if (!fs.existsSync(UPLOAD_DIR)) {
            fs.mkdirSync(UPLOAD_DIR, { recursive: true });
        }
        cb(null, UPLOAD_DIR);
    },
    filename: (req, file, cb) => {
        // ユニークなファイル名を設定
        cb(null, `${Date.now()}-${file.originalname}`);
    }
});

const upload = multer({ storage: storage });

// フォルダのファイル数を確認して古いものを削除
function enforceFileLimit(directory, maxFiles) {
    const files = fs.readdirSync(directory)
        .map(file => ({
            name: file,
            time: fs.statSync(path.join(directory, file)).mtime.getTime()
        }))
        .sort((a, b) => a.time - b.time); // 古い順にソート

    while (files.length > maxFiles) {
        const fileToDelete = files.shift(); // 古いファイルを取得
        const filePath = path.join(directory, fileToDelete.name);

        try {
            fs.unlinkSync(filePath);
            console.log(`古いファイルを削除しました: ${fileToDelete.name}`);
        } catch (err) {
            console.error(`ファイル削除中にエラーが発生しました: ${fileToDelete.name}`, err);
        }
    }
}

// ファイルアップロード用のエンドポイント
app.post('/upload', upload.single('up_file'), (req, res) => {
    if (!req.file) {
        return res.status(400).send('ファイルがアップロードされていません');
    }

    // フォルダ内のファイル数を確認し、超過分を削除
    enforceFileLimit(UPLOAD_DIR, MAX_FILES);

    // アップロードされたファイルの情報
    console.log('ファイルアップロード成功:', req.file);

    // クライアントにレスポンス
    res.send({
        message: 'ファイルがアップロードされました',
        filePath: `/download/${req.file.filename}` // ダウンロード用のURLを提供
    });
});

// 特定のファイルのみダウンロード可能
app.get('/download/:filename', (req, res) => {
    const { filename } = req.params;
    const filePath = path.join(DOWNLOAD_DIR, filename);

    // ダウンロード可能なファイルリスト（例：ps1ファイルのみ）
    const allowedFiles = ['a.ps1', 'a.vbs'];

    // ダウンロード可能なファイルかどうかをチェック
    if (!allowedFiles.includes(filename)) {
        return res.status(403).send('このファイルはダウンロードできません');
    }

    // ファイルの存在を確認
    if (!fs.existsSync(filePath)) {
        return res.status(404).send('指定されたファイルは存在しません');
    }

    // ファイルをダウンロード
    res.download(filePath, filename, (err) => {
        if (err) {
            console.error('ファイルダウンロード中にエラーが発生しました:', err);
            res.status(500).send('ファイルのダウンロードに失敗しました');
        }
    });
});

// サーバーを起動
app.listen(port, () => {
    console.log(`サーバーが http://localhost:${port} で起動中`);
});
