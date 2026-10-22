# Focus 🌐

> **Navegador minimalista, teclado-primeiro e ultrarrápido para o ecossistema Omarchy.**  
> Construído em **Rust**, **Qt6 WebEngine (Chromium)** e com suporte a alternância para **Firefox / Zen Browser (Gecko)**.

---

## ✨ Características

* **Janela Totalmente Limpa (Chromeless)**: Sem abas pesadas ou barras ocupando espaço. Apenas a web pura em tela cheia com cantos arredondados e suporte ao tema do sistema.
* **Lançador Superior Expansível (Launcher / Omnibar)**:
  * Invoque a qualquer momento pressionando `Espaço` (quando fora de um input) ou encostando o mouse no topo da tela (ou `Ctrl+L`).
  * Conforme você digita, o lançador expande suavemente um card central estilo **Walker / Flea** com resultados em tempo real:
    * URLs diretas
    * Busca no Google (ou no motor configurado)
    * Favoritos e histórico sincronizados do seu Google Chrome / Chromium
  * Barra inferior com ações rápidas: Voltar, Avançar, Recarregar, Início, Alternância de Motor, Sincronização Chrome e Configurações.
* **Alternância de Motores Web (Chromium ⇄ Firefox/Zen)**:
  * Motor Primário Embutido: **Qt6 WebEngine** (Blink / V8) com aceleração de hardware e alto desempenho.
  * Motor Secundário: **Zen Browser / Firefox / LibreWolf** (Gecko) com perfil dedicado para máxima privacidade.
  * Alterne entre os motores com 1 clique direto no lançador ou nas configurações.
* **Login na Conta Google & Sincronização**:
  * Sessões persistentes completas para Gmail, YouTube, Google Drive e login unificado da conta Google.
  * Importação e sincronização local contínua de favoritos e histórico direto do perfil do Google Chrome / Chromium (`~/.config/google-chrome` ou `~/.config/chromium`).
  * 100% integrado com o tema ao vivo do Omarchy (`~/.local/state/omarchy/current/theme/colors.toml`).

---

## ⌨️ Atalhos Principais

| Atalho | Ação |
| :--- | :--- |
| `Espaço` | Abrir / Fechar o Lançador Superior |
| `Ctrl + L` / `F6` | Focar no Lançador Superior / Barra de Endereço |
| `Ctrl + ,` | Abrir a Janela de Configurações |
| `Ctrl + R` / `F5` | Recarregar página |
| `Esc` | Fechar Lançador ou Configurações |
| `Cursor no topo` | Revela o lançador automaticamente ao passar o mouse na borda superior |

---

## 🛠️ Tecnologias

* **Linguagem Principal**: Rust (Edição 2024)
* **Motor Web**: Qt6 WebEngine (`qt6-webengine`)
* **Interface (UI)**: QtQuick / QML com integração viva de tema Omarchy
* **Compilação**: Cargo + CMake (para a ponte C++/Qt6)

---

## 🚀 Como Compilar e Executar

Certifique-se de ter instalado no sistema:
```bash
sudo pacman -S qt6-webengine qt6-declarative cmake rust
```

Compile e execute em modo de desenvolvimento:
```bash
cargo run
```

Para compilar em modo release com otimizações máximas:
```bash
cargo build --release
./target/release/focus
```

---

## 📂 Estrutura do Projeto

```
Focus/
├── Cargo.toml               # Configuração do pacote Rust
├── build.rs                 # Script de compilação da ponte C++/Qt6
├── CMakeLists.txt           # Build da ponte Qt6 WebEngine
├── src/
│   ├── main.rs              # Ponto de entrada, inicialização e IPC
│   ├── config.rs            # Gerenciamento de configurações (~/.config/focus)
│   ├── theme.rs             # Parser de temas do Omarchy (colors.toml)
│   ├── sync.rs              # Sincronização com perfil do Google Chrome/Chromium
│   ├── engines.rs           # Gerenciador dos motores Chromium e Firefox/Zen
│   └── bridge/              # Ponte C++ FFI para Qt6 WebEngine
└── ui/
    ├── main.qml             # Janela principal limpa e container WebEngine
    ├── Launcher.qml         # Lançador expansível no topo
    ├── SettingsModal.qml    # Modal flutuante de configurações (estilo Flea)
    ├── Theme.qml            # Singleton de tema Omarchy
    └── qmldir               # Definições de módulos QML
```
