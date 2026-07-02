const app = require('./app');

const port = 9911;

app.listen(port, () => {
  console.log(`Server is listening on port ${port}`);
});
