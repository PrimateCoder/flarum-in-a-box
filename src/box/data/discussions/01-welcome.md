## 👋 Welcome to Flarum-In-A-Box!

**Flarum-In-A-Box** is a ready-to-run, all-in-one Docker container from [🎹 Piano | Tell](https://pianotell.com) that gives you a fully working **Flarum 1.8** forum with 40+ extensions pre-installed. No setup, no configuration — just launch and go.

### What is it good for?

- 🧪 **Demo & Evaluation** — Quickly show off Flarum to stakeholders, clients, or your team without setting up a server
- 💻 **Extension Development** — A clean, reproducible Flarum environment to build and test extensions against
- 📚 **Learning & Experimentation** — Explore Flarum features, try out extensions, and learn how everything works
- 🎓 **Workshops & Training** — Spin up identical instances for every participant in minutes

### Default Accounts

| Account | Username | Password | Role |
|---------|----------|----------|------|
| Admin | `admin` | `password` | Full Admin Panel access |
| Moderator | `moderator` | `password` | Moderator group — can lock, hide, suspend, etc. |
| Member | `user` | `password` | Regular forum member |
| Members | `user1` … `user5` | `password` | Sample members (used in the Moderation Playground discussion) |

The admin account has full access to the Admin Panel (click your avatar → Administration). New users can sign up without email confirmation.

### Important Notes

- ⚠️ **Demo/playground image** — fantastic for testing and development, but not for production. Data is ephemeral for the lifetime of the container.
- 🔑 Change the default passwords if exposing this beyond localhost.
- 📦 Want Flarum 2.x instead? This is the Flarum 1.x edition (the `0.1` image tag) — the Flarum 2.x edition is the `latest` tag of the same repository.

### Join the Conversation 💬

Loving Flarum-In-A-Box? Found a bug, have an extension idea, or just want to say hi? Come chat with us in the [**community thread on discuss.flarum.org**](https://discuss.flarum.org/d/39191-flarum-in-a-box-try-flarum-2x-in-one-command-with-docker) — your feedback shapes what comes next!

Have fun exploring Flarum! 🚀
