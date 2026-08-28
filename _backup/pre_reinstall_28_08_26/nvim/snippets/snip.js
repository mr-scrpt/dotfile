module.exports = {
  reactFunctionalComponent: {
    key: "reactFunctionalComponent",
    prefix: "rfce",
    body: [
      "import type { ComponentProps } from 'react';",
      " ",
      `type \${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() +
        str.slice(1)}/}Props = ComponentProps<'div'>;`,
      " ",
      `export const \${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() +
        str.slice(1)}/} = (props: \${TM_FILENAME_BASE/(.*)/${(str) =>
        str.charAt(0).toUpperCase() + str.slice(1)}/}Props) => {`,
      "  const { children, ...rest } = props;",
      " ",
      "  return (",
      "    <div {...rest}>",
      "      ${1:Content}",
      "    </div>",
      "  );",
      "};",
      " ",
    ],
    description: "Creates a modern React Functional Component",
    scope: "typescript,typescriptreact",
  },
};
