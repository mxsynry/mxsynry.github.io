export function normalizeNode(node, parentPath = "") {
  if (!node) return null;
  const name = node.name || "Repository";
  const type =
    node.type === "tree"
      ? "dir"
      : node.type === "blob"
        ? "file"
        : node.type || "dir";
  const path = parentPath ? parentPath + "/" + name : node.path || "";
  const normalized = {
    ...node,
    name,
    type,
    path: node.path || path,
    fullPath: node.fullPath || node.path || path,
    size: node.size,
    html_url: node.html_url,
    download_url: node.download_url,
  };
  if (type === "dir") {
    normalized.children = (node.children || [])
      .map((child) => normalizeNode(child, normalized.fullPath))
      .filter(Boolean);
  }
  return normalized;
}

export function findNode(root, path) {
  if (!path) return root;
  const parts = path.split("/").filter(Boolean);
  let node = root;
  for (const part of parts) {
    if (!node || !node.children) return null;
    node = node.children.find((c) => c.name === part);
  }
  return node || null;
}

export function getAllFiles(node, prefix = "") {
  const files = [];
  if (!node || !node.children) return files;
  for (const child of node.children) {
    const p = prefix ? prefix + "/" + child.name : child.name;
    if (child.type === "dir") files.push(...getAllFiles(child, p));
    else files.push({ ...child, fullPath: p });
  }
  return files;
}

export function countFiles(node) {
  if (!node) return 0;
  if (node.type === "file") return 1;
  return (node.children || []).reduce(
    (sum, child) => sum + countFiles(child),
    0,
  );
}
