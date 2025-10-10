document.addEventListener("DOMContentLoaded", () => {
  // Ищем контейнер, куда будем вставлять наши поля
  const container = document.getElementById("data-container");

  // Проверяем, существует ли глобальная переменная с нашими данными
  // Эту переменную создаст наш bash-скрипт
  if (typeof window.__SECRET_DATA__ === "undefined" || !container) {
    return;
  }

  // Разбиваем сырые данные на строки
  const lines = window.__SECRET_DATA__.trim().split("\n");
  let isFirstLine = true;

  // Обрабатываем каждую строку
  lines.forEach((line) => {
    let labelText, valueText;

    if (isFirstLine) {
      labelText = "Password";
      valueText = line;
      isFirstLine = false;
    } else {
      if (line.includes(":")) {
        labelText = line.substring(0, line.indexOf(":"));
        valueText = line.substring(line.indexOf(":") + 1).trim();
      } else {
        labelText = "Note";
        valueText = line;
      }
    }

    // --- Создаем HTML-элементы с помощью JS ---
    const fieldDiv = document.createElement("div");
    fieldDiv.className = "field";

    const labelDiv = document.createElement("div");
    labelDiv.className = "label";
    labelDiv.textContent = `${labelText}:`;

    const valueInput = document.createElement("input");
    valueInput.className = "value";
    valueInput.type = "password";
    valueInput.value = valueText;
    valueInput.readOnly = true;
    valueInput.addEventListener("click", () => {
      valueInput.type = valueInput.type === "password" ? "text" : "password";
    });

    const copyButton = document.createElement("button");
    copyButton.className = "copy-btn";
    copyButton.textContent = "Copy";
    copyButton.addEventListener("click", (e) => {
      e.stopPropagation();
      navigator.clipboard.writeText(valueText).then(() => {
        const originalText = copyButton.textContent;
        copyButton.textContent = "Copied!";
        setTimeout(() => {
          copyButton.textContent = originalText;
        }, 1000);
      });
    });

    fieldDiv.appendChild(labelDiv);
    fieldDiv.appendChild(valueInput);
    fieldDiv.appendChild(copyButton);

    container.appendChild(fieldDiv);
  });
});
