# Traduz os rótulos ("key") de um config do fastfetch para o idioma indicado
# em -v lang=xx, usando a tabela labels.tsv.
#
#   awk -v lang=pt -f translate-labels.awk labels.tsv config.jsonc
#
# A tabela é lida em ambos os sentidos: a última palavra de cada rótulo (em
# qualquer idioma) identifica a coluna, de modo que um config já traduzido
# também é reconhecido e reescrito. Idioma ausente da tabela cai no inglês,
# que são os próprios nomes das colunas. Rótulos desconhecidos (WM, CPU,
# GPU, RAM...) e o restante do arquivo passam intactos.

function lastword(s,   off, pos, len) {
    off = 0; pos = 0; len = 0
    while (match(s, /[[:alpha:]]+/)) {
        pos = off + RSTART
        len = RLENGTH
        off += RSTART + RLENGTH - 1
        s = substr(s, RSTART + RLENGTH)
    }
    LW_POS = pos
    LW_LEN = len
    return pos ? "yes" : ""
}

function register(cell, column,   w) {
    if (lastword(cell) == "") return
    w = tolower(substr(cell, LW_POS, LW_LEN))
    column_of[w] = column
}

# Colunas ocupadas no terminal. Ideogramas, kana, hangul e formas de largura
# total ocupam duas. Só é possível distinguir caracteres com o awk em locale
# UTF-8; fora dele, length() conta bytes (3 por ideograma), o que
# superestima a largura, mas nunca a subestima.
function columns(s,   n) {
    if (!UTF8) return length(s)
    n = gsub(/[ᄀ-ᅟ⺀-〾ぁ-㉇㐀-䶿一-鿿ꀀ-꓏가-힣豈-﫿︐-︙︰-﹫！-｠￠-￦]/, "&", s)
    return length(s) + n
}

BEGIN { FS = "\t"; UTF8 = (length("é") == 1) }

# 1ª passagem: tabela de rótulos.
NR == FNR {
    if (FNR == 1) {
        for (i = 2; i <= NF; i++) {
            column[i] = $i
            # Inglês (fallback) = nome da coluna capitalizado.
            label[$i] = toupper(substr($i, 1, 1)) substr($i, 2)
            register($i, $i)
        }
        next
    }
    for (i = 2; i <= NF; i++) {
        register($i, column[i])
        if ($1 == lang) label[column[i]] = $i
    }
    next
}

# 2ª passagem: config do fastfetch.
{
    if ($0 ~ /"keyWidth"[ \t]*:/) next   # recalculado no END

    if ($0 ~ /"key"[ \t]*:/ && match($0, /:[ \t]*"[^"]*"/)) {
        seg = substr($0, RSTART, RLENGTH)
        head = substr($0, 1, RSTART - 1)
        tail = substr($0, RSTART + RLENGTH)

        if (lastword(seg) != "") {
            word = substr(seg, LW_POS, LW_LEN)
            key = column_of[tolower(word)]
            if (key != "" && label[key] != "") {
                # Rótulo em minúsculas no config continua em minúsculas.
                tr = (word == tolower(word)) ? tolower(label[key]) : label[key]
                seg = substr(seg, 1, LW_POS - 1) tr substr(seg, LW_POS + LW_LEN)
            }
        }

        # Largura da chave, sem as aspas e sem espaços de alinhamento.
        text = ""
        if (match(seg, /"[^"]*"/)) {
            text = substr(seg, RSTART + 1, RLENGTH - 2)
            gsub(/\{#[^}]*\}/, "", text)        # cores ({#...}) não ocupam coluna
            gsub(/\\u001b(\[[0-9;]*)?[0-9A-Za-z]/, "", text)  # escapes (\u001b7, \u001b[K...)
            gsub(/[─ ]+$/, "", text)            # traço de divisória ("├─ hardware ───")
            gsub(/\{[a-z0-9-]+\}/, "x", text)   # {icon} vira um caractere
            gsub(/[ \t]+$/, "", text)
            if (columns(text) > key_width) key_width = columns(text)
        }

        $0 = head seg tail
        # Chave vazia (só cor, como "{#}"): linha sem rótulo, não alinhada.
        is_key[n + 1] = (text != "")
    }

    line[++n] = $0
}

END {
    if (key_width > 0) key_width += 4   # três colunas de respiro até o valor
    for (i = 1; i <= n; i++) {
        # keyWidth é propriedade de módulo; entra antes da "key", posição
        # sempre válida (a pontuação da linha original é preservada).
        if (is_key[i] && key_width > 0) {
            match(line[i], /^[ \t]*/)
            print substr(line[i], 1, RLENGTH) "\"keyWidth\": " key_width ","
        }
        print line[i]
    }
}
