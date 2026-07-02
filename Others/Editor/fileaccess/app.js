const express = require('express');
const fs = require('fs');
const path = require('path');
const bodyParser = require('body-parser');

const app = express();

app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

app.get('/files', async (req, res) => {
    const directoryPath = path.join(__dirname, 'SolaraTab');
    try {
        const fileNames = await fs.promises.readdir(directoryPath);
        const filePromises = fileNames.map(async (fileName) => {
            if (fileName !== "undefined") {
                const filePath = path.join(directoryPath, fileName);
                const stats = await fs.promises.stat(filePath);
                return { name: fileName, createdAt: stats.birthtime };
            } else {
                const filePath = path.join(directoryPath, "main.lua");
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
    const filename = req.params.filename;
    const filePath = path.join(__dirname, 'SolaraTab', filename);

    try {
        await fs.promises.unlink(filePath);
        res.send(`${filename} has been deleted.`);
    } catch (err) {
        console.error('Error deleting file:', err);
        res.status(500).send('Error deleting file');
    }
});

app.post('/addtab/:filename', async (req, res) => {
    const filename = req.params.filename;
    const filePath = path.join(__dirname, 'SolaraTab', `${filename}.lua`);

    try {
        await fs.promises.writeFile(filePath, '', { flag: 'wx' });
        res.status(201).send(`${filename}.lua has been created.`);
    } catch (err) {
        console.error('Error creating file:', err);
        if (err.code === 'EEXIST') {
            return res.status(409).send(`${filename}.lua already exists.`);
        }
        res.status(500).send('Error creating file');
    }
});

app.get('/opentab/:filename', async (req, res) => {
    const { filename } = req.params;
    const filePath = path.join(__dirname, 'SolaraTab', filename);

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
    const { filename } = req.params;
    const filePath = path.join(__dirname, 'SolaraTab', filename);
    const fileContent = req.body;

    try {
        await fs.promises.writeFile(filePath, fileContent);
        res.send('File saved successfully');
    } catch (error) {
        console.error('Error saving file:', error);
        res.status(500).send('Error saving file');
    }
});

module.exports = app;
