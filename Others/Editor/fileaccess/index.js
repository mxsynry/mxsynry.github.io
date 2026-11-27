const path = require("node:path");
const { createApp } = require("./app.js");

const port = Number(process.env.PORT || 9911);
const directory =
  process.env.EDITOR_FILES_DIR || path.join(__dirname, "SolaraTab");

createApp(directory)
  .then((app) => {
    app.listen(port, "127.0.0.1", () => {
      console.log(`Editor file service: http://127.0.0.1:${port}`);
    });
  })
  .catch((error) => {
    console.error("Unable to start editor file service:", error);
    process.exitCode = 1;
  });
