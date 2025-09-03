# Navigation & listing

**pwd**

* `-P` chemin **physique** (résout les liens) • `pwd -P`
* `-L` chemin **logique** (par défaut) • `pwd -L`

**cd** (builtin bash)

* `cd -` revenir au dossier précédent
* `cd ~` / `cd ~user` home courant / d’un autre user
* `cd -P` physique • `cd -L` logique

**pushd / popd / dirs** (pile de dossiers)

* `pushd /etc && dirs` • `popd`

**ls**

* `-l` long • `-a` tout (incl. fichiers cachés) • `-A` tout **sauf** `.` et `..`
* `-h` tailles lisibles • `-R` récursif • `-t` trier par date • `-S` trier par taille
* `-r` ordre inverse • `-d */` n’afficher que les dirs • `-F` indicateurs (`/`, `*`, `@`)
* `--group-directories-first` dossiers en tête
* Ex. : `ls -lah --group-directories-first`

**tree** (installer : `sudo apt install tree`)

* `-L <n>` profondeur • `-d` seulement dirs • `-a` incl. cachés • `-I PATTERN` ignorer
* Ex. : `tree -L 2 -a -I ".git|node_modules"`

# Explorer / rechercher

**find** (ultra-puissant)

* Portée : `-maxdepth n` • `-mindepth n` • `-mount` ne pas traverser d’autres FS
* Filtre : `-name/-iname` • `-type f|d|l` • `-size +100M` • `-mtime -2` (2 jours) • `-mmin -30`
* Permissions & proprio : `-user`, `-group`, `-perm /222`
* Actions : `-print` (défaut) • `-delete` • `-exec cmd {} \;` • `-ok ...`
* Pruning : `-path "*/cache/*" -prune -o ... -print`
* Ex. : `find /var/log -type f -mtime -2 -size +1M -exec ls -lh {} \;`

**locate** (indexé, super rapide — `sudo apt install plocate` puis `sudo updatedb`)

* `-i` insensible casse • `-r` regex • `-n 20` limiter nb • `-c` compter
* `-b` ne matche que le **nom** de base • `-e` seulement existants
* Ex. : `locate -i -n 20 sources.list`

**whereis / which / type**

* `whereis ls` (binaires, man, sources) • options : `-b` (binaires), `-m` (man)
* `which cmd` chemin du binaire **(préférer)** `command -v` ou `type -a cmd`

**realpath / readlink**

* `realpath file` chemin absolu canonique
* `readlink -f file` résout symlinks et `..`

# Taille & stockage

**du** (taille utilisée)

* `-h` lisible • `-s` résumé • `-a` incl. fichiers • `-d <n>` profondeur
* `--max-depth=<n>` équiv. GNU • `--apparent-size` taille logique
* Ex. : `du -h --max-depth=1 . | sort -h`
  `du -sh *`

**df** (occupation des systèmes de fichiers)

* `-h` lisible • `-T` type FS • `-i` inodes • `-t ext4` n’afficher que ce type • `-x tmpfs` exclure
* Ex. : `df -hT -x tmpfs -x squashfs`

**stat**

* `-c FORMAT` format custom • `-L` suivre symlink • `-t` sortie courte • `-f` (stats du FS)
* Ex. : `stat -c '%n %s bytes %y' fichier`

# Organisation (créer/déplacer/supprimer)

**mkdir**

* `-p` parents auto • `-m 755` mode • `-v` verbeux
  Ex. : `mkdir -pv proj/{bin,src,docs}`

**rmdir**

* `-p` supprime parents vides • `--ignore-fail-on-non-empty` • `-v`
* Ex. : `rmdir -pv vide/sousdir`

**rm** ⚠️

* `-r` récursif • `-f` forcé • `-i` interactif • `-I` confirmation “douce” • `-v`
* `-d` supprimer **dossier vide**
  Ex. : `rm -rf build/` (dangereux — vérifie le chemin!)

**mv**

* `-i` demander • `-f` forcer • `-n` no-clobber • `-v` • `-t DIR` préciser la cible
  Ex. : `mv -vn *.log -t /tmp/`

**cp**

* `-r` récursif • `-a` archive (= `-dR --preserve=all`) • `-u` maj si plus récent
* `-p` préserver (mode, proprio, dates) • `-v` • `-i/-n` • `--parents` garder l’arbo
  Ex. : `cp -a src/ backup/` • `cp --parents etc/apt/sources.list backup/`

# Raccourcis & globbing utiles

* `.` courant • `..` parent • `~` HOME • `-` dossier précédent
* `*` tout • `?` un char • `[abc]` classe • `{a,b,c}` expansions • `**` (avec `shopt -s globstar`)
* Complétion **Tab** ; historique avec `Ctrl+R`.

# Atelier “minute” (sécuritaire)

```bash
mkdir -p ~/lab/linux/{data,logs,bin}
touch ~/lab/linux/logs/{app.log,sys.log} ~/lab/linux/data/{a.txt,b.txt}
cd ~/lab/linux

# Lister intelligemment
ls -lah --group-directories-first
ls -lR | less
tree -L 2 -a

# Rechercher
find . -maxdepth 2 -type f -name "*.log" -printf "%p\t%k KB\n"
find . -type f -size +0 -mtime -7 -print
locate -n 10 sources.list

# Tailles
du -h --max-depth=1 .
df -hT -x tmpfs

# Organisation
cp -av data bin/        # copie avec attributs
mv -vn logs/*.log /tmp/ # déplacer sans écraser
rm -d logs              # supprimer dir vide
```
