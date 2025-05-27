module.exports = {
  reactFunctionalExportComponent: {
    key: "reactFunctionalExportComponent",
    prefix: "rfce",
    body: [
      "import { FC, HTMLAttributes } from 'react'",
      "",
      `interface \${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() +
        str.slice(1)}/}Props extends HTMLAttributes<HTMLDivElement> {}`,
      "",
      `export const \${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() +
        str.slice(1)}/}: FC<\${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() + str.slice(1)}/}Props> = (props) => {`,
      "  return (",
      "    <div>${1:first}</div>",
      "  )",
      "}",
      "",
    ],
    description: "Creates a React Functional Component with ES7 module system",
    scope: "typescript,typescriptreact,javascript,javascriptreact",
  },
};
