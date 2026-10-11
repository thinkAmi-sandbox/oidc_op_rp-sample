# rails-load-defaults（`load_defaults` を上げる）

## 入口の条件

- rails-defaults が終わり、`new_framework_defaults_*.rb` のすべての設定が有効になっている

## 手順

1. 前の書き出しを取る（[before-after.md](before-after.md)）
2. `load_defaults` を上げ、`new_framework_defaults_*.rb` と、そのために足した設定を消す
3. 新しい版の雛形から消えた initializer を、雛形と比べて消すかを決める（消すものは追随の項目にする）
4. 後の書き出しを取って比べる。違いがあれば理由を確かめる（起動の途中の読み込みで、グループのときは効かなかった設定など）
5. 追随の解説（[explain.md](explain.md)）。返事の後に、アプリごとにコミットする
6. 静的解析の対象の Rails の版を、別のコミットで上げる

## 関門

- 理解の関門: 既定値への追随（消す initializer を含む）

## 出口の条件と記録

- 前後の比較の結果と、消したもの・残したものを、記録の Step の節に足した。設定の「計画」のチェックリストの、この作業の項目を済みにし、docs のコミットにする（セッションが変わっても、resume が続きから始められるようにするため）
