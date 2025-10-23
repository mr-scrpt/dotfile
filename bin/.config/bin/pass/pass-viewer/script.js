document.addEventListener("DOMContentLoaded", () => {
  const mainContainer = document.getElementById("main-container");
  const metaContainer = document.getElementById("meta-container");

  if (
    typeof window.__SECRET_DATA__ === "undefined" ||
    !mainContainer ||
    !metaContainer
  ) {
    return;
  }

  // --- Хелпер-функция для создания одного поля ---
  function createField(label, value, isSecretByDefault) {
    const fieldDiv = document.createElement("div");
    fieldDiv.className = "field";

    const labelDiv = document.createElement("div");
    labelDiv.className = "label";
    labelDiv.textContent = `${label}:`;

    const valueWrapper = document.createElement("div");
    valueWrapper.className = "value-wrapper";

    const valueInput = document.createElement("input");
    valueInput.className = "value";
    valueInput.type = isSecretByDefault ? "password" : "text";
    valueInput.value = value;
    valueInput.readOnly = true;

    const toggleIcon = document.createElement("i");
    toggleIcon.className =
      "toggle-vis fas " + (isSecretByDefault ? "fa-eye" : "fa-eye-slash");
    toggleIcon.addEventListener("click", () => {
      if (valueInput.type === "password") {
        valueInput.type = "text";
        toggleIcon.className = "toggle-vis fas fa-eye-slash";
      } else {
        valueInput.type = "password";
        toggleIcon.className = "toggle-vis fas fa-eye";
      }
    });

    const copyButton = document.createElement("button");
    copyButton.className = "copy-btn";
    copyButton.textContent = "Copy";
    copyButton.addEventListener("click", () => {
      navigator.clipboard.writeText(value).then(() => {
        const originalText = copyButton.textContent;
        copyButton.textContent = "Copied!";
        setTimeout(() => {
          copyButton.textContent = originalText;
        }, 1000);
      });
    });

    valueWrapper.appendChild(valueInput);
    valueWrapper.appendChild(toggleIcon);
    fieldDiv.appendChild(labelDiv);
    fieldDiv.appendChild(valueWrapper);
    fieldDiv.appendChild(copyButton);

    return fieldDiv;
  }

  // --- Основная логика ---
  const lines = window.__SECRET_DATA__.trim().split("\n");

  // 1. Обрабатываем первую строку (главный пароль)
  const mainSecretValue = lines.shift(); // Взять и удалить первую строку
  if (mainSecretValue) {
    const mainHeader = document.createElement("h3");
    mainHeader.textContent = "Main Secret";
    mainContainer.appendChild(mainHeader);
    mainContainer.appendChild(createField("Password", mainSecretValue, true));
  }

  // 2. Обрабатываем остальные строки (метаданные)
  if (lines.length > 0) {
    const metaHeader = document.createElement("h3");
    metaHeader.textContent = "Metadata";
    metaContainer.appendChild(metaHeader);

    lines.forEach((line) => {
      let label,
        value,
        isSecret = false;

      // Проверяем на специальный маркер "(s)"
      if (line.match(/^(.*)\(s\):(.*)$/)) {
        label = line.match(/^(.*)\(s\):(.*)$/)[1].trim();
        value = line.match(/^(.*)\(s\):(.*)$/)[2].trim();
        isSecret = true;
      } else if (line.includes(":")) {
        label = line.substring(0, line.indexOf(":"));
        value = line.substring(line.indexOf(":") + 1).trim();
        isSecret = false;
      } else {
        label = "Note";
        value = line;
        isSecret = false;
      }

      metaContainer.appendChild(createField(label, value, isSecret));
    });
  }
});
