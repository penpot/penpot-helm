# Penpot Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/penpot)](https://artifacthub.io/packages/search?repo=penpot)

This repository contains charts for Penpot (https://penpot.app) project.


## What is Penpot

Penpot is the first **open-source** design tool for design and code collaboration. Designers can create stunning designs, interactive prototypes, design systems at scale, while developers enjoy ready-to-use code and make their workflow easy and fast. And all of this with no handoff drama.

Penpot is available on browser and [self host](https://penpot.app/self-host). It’s web-based and works with open standards (SVG, CSS and HTML). And last but not least, it’s free!


## Usage

The charts can be added using following command:

```
helm repo add penpot https://helm.penpot.app/
```
## Prerequisites

This chart uses **CloudNativePG (CNPG)** to manage PostgreSQL clusters.

Before installing Penpot, the CloudNativePG operator must be installed in the cluster:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm install cnpg-operator cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace
```
## Migration from existing installations

This chart supports migrating existing Penpot installations, including legacy deployments such as Bitnami-based setups.

A Penpot installation stores data in two different places:

- **PostgreSQL database** (users, teams, projects, metadata)
- **Filesystem assets** (thumbnails, previews, and file blobs)

Migrating only the database is not sufficient.  
If assets are not migrated, boards and dashboards may appear broken or show missing thumbnails after the migration.

To address this, this repository includes a migration script that performs an **end-to-end migration**, ensuring data consistency across both layers.

### What the migration process does

The migration workflow:

- Temporarily stops Penpot services to avoid writes
- Creates a backup of the source PostgreSQL database
- Restores the database into the target installation
- Migrates filesystem assets stored under `/opt/data/assets`
- Preserves existing PVCs and safely replaces their contents

This approach prevents common migration issues such as missing thumbnails or partially rendered boards.

### Migration script

The migration helper script is located at:

```bash
scripts/migrate.sh
```
It is intended to be used when migrating existing Penpot installations to a new deployment.

> 📌 **Note**
> The migration tooling is intended for existing installations only.
> For fresh deployments, no migration steps are required.

By default, the script assumes the following namespaces:

- Source namespace: penpot
- Target namespace: penpot-migration

> 📌 **Note**
> The namespace names used in the script are examples.
> Users should update them according to their own Kubernetes environment.

This migration process is designed to be safe, repeatable, and suitable for production environments.

## Contributing ##

We'd love to have you contribute! Please refer to our [contribution guidelines](/CONTRIBUTING.md) for details if you want to contribute to this repository or visit the [Contributing](https://github.com/penpot/penpot/tree/develop?tab=readme-ov-file#contributing) section in the main project repository to discover other ways to contribute.


## Community

We love the Open Source software community. Contributing is our passion and if it’s yours too, participate and [improve](https://community.penpot.app/c/help-us-improve-penpot/7) Penpot. All your designs, code and ideas are welcome!

If you need help or have any questions; if you’d like to share your experience using Penpot or get inspired; if you’d rather meet our community of developers and designers, [join our Community](https://community.penpot.app/)!

You will find the following categories:

- [Ask the Community](https://community.penpot.app/c/ask-for-help-using-penpot/6)
- [Troubleshooting](https://community.penpot.app/c/technical/8)
- [Help us Improve Penpot](https://community.penpot.app/c/help-us-improve-penpot/7)
- [#MadeWithPenpot](https://community.penpot.app/c/madewithpenpot/9)
- [Events and Announcements](https://community.penpot.app/c/announcements/5)
- [Inside Penpot](https://community.penpot.app/c/inside-penpot/21)
- [Penpot in your language](https://community.penpot.app/c/penpot-in-your-language/12)
- [Design and Code Essentials](https://community.penpot.app/c/design-and-code-essentials/22)


## Resources

You can ask and answer questions, have open-ended conversations, and follow along on decisions affecting the project.

💾 [Documentation](https://help.penpot.app/technical-guide/)

🚀 [Getting Started](https://help.penpot.app/technical-guide/getting-started/)

✏️ [Tutorials](https://www.youtube.com/playlist?list=PLgcCPfOv5v54WpXhHmNO7T-YC7AE-SRsr)

🏘️ [Architecture](https://help.penpot.app/technical-guide/developer/architecture/)

📚 [Dev Diaries](https://penpot.app/dev-diaries.html)


## License ##

```
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) KALEIDOS INC
```
Penpot is a Kaleidos’ [open source project](https://kaleidos.net/)
