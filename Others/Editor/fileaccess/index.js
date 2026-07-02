const express = require('express');
const fs = require('fs');
const path = require('path');
const bodyParser = require('body-parser');

const app = express();
const port = 9911;

const ALLOWED_ORIGINS = [
    'http://localhost:9911',
    'http://127.0.0.1:9911'
];

const TABS_DIR = path.join(__dirname, 'SolaraTab');

function safePath(filename) {
    const basename = path.basename(filename);
    if (!basename || basename === '.' || basename === '..') return null;
    const resolved = path.resolve(TABS_DIR, basename);
    if (!resolved.startsWith(TABS_DIR + path.sep) && resolved !== TABS_DIR) return null;
    return resolved;
}

app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (ALLOWED_ORIGINS.includes(origin)) {
        res.header('Access-Control-Allow-Origin', origin);
    }
    res.header('Access-Control-Allow-Methods', 'GET, POST, DELETE');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

app.get('/files', async (req, res) => {
    try {
        const fileNames = await fs.promises.readdir(TABS_DIR);
        const filePromises = fileNames.map(async (fileName) => {
            if (fileName !== "undefined") {
                const filePath = path.join(TABS_DIR, fileName);
                const stats = await fs.promises.stat(filePath);
                return { name: fileName, createdAt: stats.birthtime };
            } else {
                const filePath = path.join(TABS_DIR, "main.lua");
                const stats = await fs.promises.stat(filePath);
                return { name: fileName, createdAt: stats.birthtime };
            }
        });
        const files = await Promise.all(filePromises);
        const sortedFiles = files.sort((a, b) => a.createdAt - b.createdAt);
        res.json(sortedFiles);
    } catch (err) {
        console.error('Error reading directory:', err);
        res.status(500).send('Error reading directory');
    }
});

app.delete('/delete/:filename', async (req, res) => {
    const filePath = safePath(req.params.filename);
    if (!filePath) return res.status(400).send('Invalid filename');

    try {
        await fs.promises.unlink(filePath);
        res.send(`${path.basename(filePath)} has been deleted.`);
    } catch (err) {
        console.error('Error deleting file:', err);
        res.status(500).send('Error deleting file');
    }
});

app.post('/addtab/:filename', async (req, res) => {
    const basename = path.basename(req.params.filename);
    const filePath = safePath(`${basename}.lua`);
    if (!filePath) return res.status(400).send('Invalid filename');

    try {
        await fs.promises.writeFile(filePath, '', { flag: 'wx' });
        res.status(201).send(`${path.basename(filePath)} has been created.`);
    } catch (err) {
        console.error('Error creating file:', err);
        if (err.code === 'EEXIST') {
            return res.status(409).send(`${path.basename(filePath)} already exists.`);
        }
        res.status(500).send('Error creating file');
    }
});

app.get('/opentab/:filename', async (req, res) => {
    const filePath = safePath(req.params.filename);
    if (!filePath) return res.status(400).send('Invalid filename');

    try {
        const data = await fs.promises.readFile(filePath, 'utf8');
        res.send(data);
    } catch (error) {
        console.error('Error reading file:', error);
        res.status(500).send('Error reading file');
    }
});

app.use(bodyParser.text());

app.post('/savetab/:filename', async (req, res) => {
    const filePath = safePath(req.params.filename);
    if (!filePath) return res.status(400).send('Invalid filename');
    const fileContent = req.body;

    try {
        await fs.promises.writeFile(filePath, fileContent);
        res.send('File saved successfully');
    } catch (error) {
        console.error('Error saving file:', error);
        res.status(500).send('Error saving file');
    }
});

app.listen(port, '127.0.0.1', () => {
    console.log(`Server is listening on http://127.0.0.1:${port}`);
});
