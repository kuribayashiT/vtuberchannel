// 選択中の事務所名を取得
function getSelectedOffice() {
    const selectedPanel = document.querySelector('.office-panel-cute.selected');
    console.log('[getSelectedOffice] selectedPanel:', selectedPanel);

    if (!selectedPanel) {
        console.log('[getSelectedOffice] return: (no selectedPanel) null');
        return null;
    }
    let office = selectedPanel.getAttribute('data-office');
    console.log('[getSelectedOffice] data-office:', office);
    if (!office) {
        console.log('[getSelectedOffice] return: (no office) null');
        return null;
    }
    if (office === 'other') {
        const customOfficeKey = document.getElementById('customOfficeKey');
        if (customOfficeKey && typeof customOfficeKey.value === 'string' && customOfficeKey.value.trim()) {
            console.log('[getSelectedOffice] return: customOfficeKey', customOfficeKey.value.trim());
            return customOfficeKey.value.trim();
        }
        console.log('[getSelectedOffice] return: (other, no customOfficeKey) null');
        return null;
    }
    console.log('[getSelectedOffice] return:', office);
    return office;
}
// シンプルな進捗表示用ダミー関数（未定義エラー対策）
function showProgress(show, percent) {
    // 必要に応じて進捗バーやローディングUIを実装
    // ここではコンソール出力のみ
    if (show) {
        console.log('進捗:', percent ? percent + '%' : '表示');
    } else {
        console.log('進捗: 非表示');
    }
}
// Firebase SDKを使わないシンプル認証システム

// 認証チェック
function checkAuthentication() {
    console.log('🔍 認証チェック開始');
    const adminUser = sessionStorage.getItem('adminUser');
    const authLoading = document.getElementById('authLoading');
    const mainContent = document.getElementById('mainContent');

    console.log('📄 セッションストレージ内容:', adminUser);

    if (adminUser) {
        try {
            const user = JSON.parse(adminUser);
            console.log('👤 パースされたユーザー情報:', user);

            if (user.isAdmin) {
                console.log('✅ 管理者として認証成功');
                // 認証済み - メインコンテンツを表示
                const userEmailElement = document.getElementById('userEmail');
                if (userEmailElement) {
                    userEmailElement.textContent = user.email;
                }

                if (authLoading) {
                    authLoading.style.display = 'none';
                }
                if (mainContent) {
                    mainContent.style.display = 'block';
                }
                return true;
            } else {
                console.log('❌ 管理者権限なし');
            }
        } catch (e) {
            console.log('❌ JSON パースエラー:', e);
            sessionStorage.removeItem('adminUser');
        }
    } else {
        console.log('❌ セッションストレージにadminUserなし');
    }

    // 認証されていない場合はログインページにリダイレクト
    console.log('🔄 ログインページにリダイレクト');
    window.location.href = 'admin-login.html';
    return false;
}

// onsubmit="addNewVtuber(event)" 対応: handleAddVtuberをwindow.addNewVtuberにバインド
window.addNewVtuber = handleAddVtuber;

const BASE_URL = 'https://us-central1-vtuber-335811.cloudfunctions.net';
// ステータス表示
function showStatus(message, type = 'info') {
    const statusDiv = document.getElementById('status');
    if (!statusDiv) return; // statusDivがなければ何もしない
    statusDiv.innerHTML = `<div class="status ${type}">${message}</div>`;
    // 3秒後に自動削除（エラーの場合は残す）
    if (type !== 'error') {
        setTimeout(() => {
            statusDiv.innerHTML = '';
        }, 3000);
    }
    // Office選択肢を動的に生成（定義をJSに集約）
    async function loadOfficeOptions() {
        try {
            // office一覧とofficeMappingを並列取得
            const [officeRes, mappingRes] = await Promise.all([
                fetch('https://vtuber-335811-default-rtdb.firebaseio.com/office.json'),
                fetch('https://vtuber-335811-default-rtdb.firebaseio.com/officeMapping.json')
            ]);
            if (!officeRes.ok || !mappingRes.ok) throw new Error('事務所一覧またはMappingの取得に失敗しました');
            const officeRaw = await officeRes.json();
            window.officeRaw = officeRaw;
            // office.jsonがオブジェクトの場合は値を抽出
            let officeList = [];
            if (Array.isArray(officeRaw)) {
                officeList = officeRaw;
            } else if (typeof officeRaw === 'object') {
                // 数値キーやupdateTime、日付・数値データを除外し、事務所名だけ抽出
                officeList = Object.values(officeRaw).filter(v => {
                    if (typeof v !== 'string') return false;
                    if (!v || v.trim() === '') return false;
                    // updateTimeや日付形式（YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD）を除外
                    if (v.match(/updateTime/i)) return false;
                    if (v.match(/\d{4}[-\/.]\d{2}[-\/.]\d{2}/)) return false;
                    if (v.match(/\d{8}/)) return false;
                    // 数値のみ（例: 20250728）も除外
                    if (/^\d+$/.test(v)) return false;
                    // 事務所名らしいものだけ残す
                    return true;
                });
            } else {
                throw new Error('事務所データが不正です');
            }
            // デバッグ用ログ
            console.log('[DEBUG][office] officeRaw:', officeRaw);
            console.log('[DEBUG][office] officeList:', officeList);
            const officeMapping = await mappingRes.json();
            window.officeMapping = officeMapping;
            console.log('[DEBUG][office] officeMapping:', officeMapping);
            // ループ内の値も出力
            officeList.forEach((v, i) => {
                console.log(`[DEBUG][office] officeList[${i}]:`, v, '| mapping:', officeMapping[v.trim()]);
            });
            window.officeList = officeList;
            if (!officeMapping || typeof officeMapping !== 'object') {
                throw new Error('事務所マッピングデータが不正です');
            }
            if (officeList.length === 0) throw new Error('事務所データが不正です');
            generateOfficeRadioButtons(officeList, officeMapping);
        } catch (error) {
            console.error('Office取得エラー:', error);
            let debugMsg = `<b>Office取得エラー:</b> ${error.message}<br>`;
            if (typeof window.officeRaw !== 'undefined') {
                debugMsg += `<b>officeRaw:</b> <pre>${JSON.stringify(window.officeRaw, null, 2)}</pre>`;
            }
            if (typeof window.officeList !== 'undefined') {
                debugMsg += `<b>officeList:</b> <pre>${JSON.stringify(window.officeList, null, 2)}</pre>`;
            }
            if (typeof window.officeMapping !== 'undefined') {
                debugMsg += `<b>officeMapping:</b> <pre>${JSON.stringify(window.officeMapping, null, 2)}</pre>`;
            }
            showStatus(debugMsg, 'error');
            // フォールバック: デフォルト事務所
            const fallbackList = [
                'personal', 'hololive', 'holoEN', 'holoID', 'KizunaAI', 'holostars', 'nijisannji', '.LIVE', 'Vshojo', 'noripuro', 'nanashiinc', 'aogirigakuen', 'vsupo'
            ];
            const fallbackMapping = {
                KizunaAI: 'Kizuna AI', Vshojo: 'VShojo', aogirigakuen: 'あおぎり高校', dotLIVE: '.LIVE', holoEN: 'ホロライブEnglish', holoID: 'ホロライブインドネシア', hololive: 'ホロライブ', holostars: 'ホロスターズ', nanashiinc: 'ななしいんく', nijisannji: 'にじさんじ', noripuro: 'のりプロ', personal: '個人', vsupo: 'ぶいすぽっ'
            };
            generateOfficeRadioButtons(fallbackList, fallbackMapping);
        }
    }
    //     if (Object.keys(analysis.officeDistribution).length > 0) {
    //         html += '<h3>📈 事務所別分布</h3><ul>';
    //         for (const [office, count] of Object.entries(analysis.officeDistribution)) {
    //             html += `<li><strong>${office}</strong>: ${count}人</li>`;
    //         }
    //         html += '</ul>';
    //     }
    //     // 問題があるデータ
    //     if (analysis.duplicateChannelIds.length > 0) {
    //         html += '<h3>⚠️ 重複チャンネルID</h3><ul>';
    //         analysis.duplicateChannelIds.forEach(id => {
    //             html += `<li>${id}</li>`;
    //         });
    //         html += '</ul>';
    //     }
    //     if (analysis.invalidChannelIds.length > 0) {
    //         html += '<h3>❌ 無効なチャンネルID</h3><ul>';
    //         analysis.invalidChannelIds.forEach(item => {
    //             html += `<li>${item.member}: ${item.channelId}</li>`;
    //         });
    //         html += '</ul>';
    //     }
    //     document.getElementById('analysis-result').innerHTML = html;
    //     showStatus('✅ データ分析が完了しました', 'success');
    //     showProgress(false);
    // } catch (error) {
    //     console.error('Analysis error:', error);
    //     showStatus(`❌ 分析エラー: ${error.message}`, 'error');
    //     showProgress(false);
    // }
}
// ファイルアップロード処理
function handleFileUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function (e) {
        document.getElementById('importData').value = e.target.result;
        showStatus(`📄 ファイル "${file.name}" を読み込みました`, 'success');
    };
    reader.readAsText(file);
}
// データ検証のみ
async function validateData() {
    document.getElementById('importMode').value = 'validate';
    await importData();
}
// データインポート
async function importData() {
    try {
        const data = document.getElementById('importData').value.trim();
        const mode = document.getElementById('importMode').value;
        if (!data) {
            showStatus('❌ インポートするデータがありません', 'error');
            return;
        }
        // birthday必須チェック（"-"も許可）
        if (format === 'json') {
            if (Array.isArray(parsedData)) {
                for (const item of parsedData) {
                    if (!item.birthday || item.birthday.trim() === '') {
                        showStatus('❌ birthday（誕生日）は必須項目です。未入力の行があります。', 'error');
                        return;
                    }
                    if (!(item.birthday === '-' || /^\d{2}[-\/]\d{2}$/.test(item.birthday))) {
                        showStatus('❌ birthday（誕生日）は MM-DD 形式または「-」で入力してください。', 'error');
                        return;
                    }
                }
            }
        } else if (format === 'csv') {
            const lines = data.split('\n').filter(l => l.trim() !== '');
            const header = lines[0].split(',');
            const birthdayIdx = header.findIndex(h => h.trim() === 'birthday');
            if (birthdayIdx === -1) {
                showStatus('❌ CSVに birthday（誕生日）列がありません。', 'error');
                return;
            }
            for (let i = 1; i < lines.length; i++) {
                const cols = lines[i].split(',');
                const val = cols[birthdayIdx] ? cols[birthdayIdx].trim() : '';
                if (!val) {
                    showStatus(`❌ birthday（誕生日）は必須項目です。${i + 1}行目が未入力です。`, 'error');
                    return;
                }
                if (!(val === '-' || /^\d{2}[-\/]\d{2}$/.test(val))) {
                    showStatus(`❌ birthday（誕生日）は MM-DD 形式または「-」で入力してください。${i + 1}行目`, 'error');
                    return;
                }
            }
        }
        showStatus(`${mode === 'validate' ? '🔍 データを検証' : '📥 データをインポート'}しています...`, 'info');
        showProgress(true, 20);
        // データ形式を判定
        let format = 'json';
        let parsedData = data;
        if (data.startsWith('channelId,') || data.includes(',')) {
            format = 'csv';
        }
        if (format === 'json') {
            try {
                parsedData = JSON.parse(data);
            } catch (e) {
                throw new Error('JSON形式が正しくありません');
            }
        }
        showProgress(true, 50);
        const response = await fetch(`${BASE_URL}/importVtuberData`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: parsedData,
                mode: mode,
                format: format
            }),
        });
        showProgress(true, 80);
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }
        const result = await response.json();
        if (result.success) {
            if (mode === 'validate') {
                showStatus(`✅ 検証完了: ${result.importCount}件のデータを確認しました`, 'success');
                if (result.validationErrors && result.validationErrors.length > 0) {
                    showStatus(`⚠️ 検証エラー: ${result.validationErrors.join(', ')}`, 'error');
                }
            } else {
                showStatus(`✅ インポート完了: ${result.importedCount}件のデータを${mode === 'replace' ? '置換' : '統合'}しました`, 'success');
            }
        } else {
            throw new Error(result.message || 'インポートに失敗しました');
        }
        showProgress(false);
    } catch (error) {
        console.error('Import error:', error);
        showStatus(`❌ ${document.getElementById('importMode').value === 'validate' ? '検証' : 'インポート'}エラー: ${error.message}`, 'error');
        showProgress(false);
    }
}
async function handleAddVtuber(event) {
    event.preventDefault();
    let channelId = document.getElementById('channelId').value.trim();
    // ここでハンドル名なら変換
    if (channelId.startsWith('@')) {
        try {
            channelId = await convertHandleToChannelId(channelId);
        } catch (e) {
            showStatus('❌ チャンネルID変換に失敗しました: ' + e.message, 'error');
            return false;
        }
    }

    const name = document.getElementById('vtuberName').value.trim();
    const twitterName = document.getElementById('twitterName').value.trim();
    // 選択中の事務所名を取得
    let office = getSelectedOffice();
    let customOfficeKey = '';
    let customOfficeName = '';

    // 既存office一覧を取得（window.officeListはloadOfficeOptionsでセットされる想定）
    let officeArr = Array.isArray(window.officeList) ? window.officeList : [];
    // 「その他」ではなく、officeArrに含まれていない場合＝新規事務所
    if (office && !officeArr.includes(office)) {
        customOfficeKey = office;
        customOfficeName = document.getElementById('customOfficeDisplayName').value.trim();
        if (!customOfficeKey || !customOfficeName) {
            showStatus('❌ 新しい事務所のKeyと表示名を入力してください。', 'error');
            return false;
        }
        // Cloud Functions経由で事務所追加
        try {
            const addOfficeRes = await fetch('https://us-central1-vtuber-335811.cloudfunctions.net/addOffice', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ officeKey: customOfficeKey, officeName: customOfficeName })
            });
            if (!addOfficeRes.ok) {
                const errText = await addOfficeRes.text();
                console.log('addOffice API error:', errText);
                showStatus('❌ 事務所の追加APIに失敗しました', 'error');
                return false;
            }
            const addOfficeResult = await addOfficeRes.json();
            if (!addOfficeResult.success) {
                showStatus('❌ 事務所の追加APIでエラーが発生しました', 'error');
                return false;
            }
        } catch (e) {
            showStatus('❌ 事務所の追加API通信エラー', 'error');
            return false;
        }
        // office変数を新規keyで上書き
        office = customOfficeKey;
    }

    console.log('[handleAddVtuber] getSelectedOffice()直後:', office, typeof office);
    if (!office || office === '') {
        showStatus('❌ 事務所は必須項目です。必ず1つ選択してください。', 'error');
        return false;
    }
    const birthday = document.getElementById('birthday').value.trim();
    // officeFlg取得
    const officeFlgNode = document.querySelector('input[name="officeFlg"]:checked');
    const officeFlg = officeFlgNode ? officeFlgNode.value : '';
    const description = document.getElementById('description') ? document.getElementById('description').value.trim() : '';

    // debut（初配信日）は任意入力
    let debut = '';
    const debutInput = document.getElementById('debut');
    if (debutInput) {
        debut = debutInput.value.trim();
    }

    if (!channelId || !name || !birthday || officeFlg === '') {
        showStatus('❌ チャンネルID・名前・誕生日・事務所所属フラグは必須項目です。', 'error');
        return false;
    }
    // 誕生日形式チェック（MM-DDまたは-）
    if (!(birthday === '-' || /^\d{2}[-\/]\d{2}$/.test(birthday))) {
        showStatus('❌ 誕生日は MM-DD 形式または「-」で入力してください。', 'error');
        return false;
    }
    showStatus('📝 新規VTuberを登録しています...', 'info');
    showProgress(true, 30);
    try {
        // 送信データを事前に出力
        const payload = {
            channelId,
            name,
            twitterName,
            office: office == null ? '' : office,
            birthday,
            officeFlg: officeFlg === 'true',
            description
        };
        // debutが空でなければ追加
        if (debut) {
            payload.debut = debut;
        }
        console.log('[AddVtuber] 送信データ:', payload);
        const response = await fetch(`${typeof currentApiBase !== 'undefined' ? currentApiBase : BASE_URL}/addVtuberData`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload),
        });
        showProgress(true, 80);
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }
        const result = await response.json();
        if (result.success) {
            showStatus('✅ 新規VTuberを登録しました！', 'success');
            document.getElementById('addVtuberForm').reset();
            // タブを維持し、画面リフレッシュやswitchTabを呼ばない
            // 必要ならここでリスト再取得やフォームのみリセット
        } else {
            throw new Error(result.message || '登録に失敗しました');
        }
    } catch (error) {
        showStatus(`❌ 登録エラー: ${error.message}`, 'error');
    }
    showProgress(false);
    // return false; // 画面リフレッシュ防止のためreturn不要
    // 明示的にreturnしないことでsubmitのデフォルト動作を防ぐ
}
// Office選択肢を動的に生成
function generateOfficeRadioButtons(officeList, officeMapping) {
    const container = document.getElementById('office-radio-group');
    container.innerHTML = '';
    officeMapping = officeMapping || {};
    officeList.forEach((office) => {
        const key = office.trim();
        const displayName = officeMapping[key] || office;
        const panel = document.createElement('div');
        panel.className = 'office-panel-cute';
        panel.setAttribute('data-office', office);
        panel.onclick = function () { selectOffice(office); };
        panel.innerHTML = `
            <span class="office-icon">🏢</span>
            <span class="office-name">${displayName}</span>
        `;
        container.appendChild(panel);
    });
    // "その他"オプションを最後に追加
    const otherPanel = document.createElement('div');
    otherPanel.className = 'office-panel-cute';
    otherPanel.setAttribute('data-office', 'other');
    otherPanel.onclick = function () { selectOffice('other'); };
    otherPanel.innerHTML = `
        <span class="office-icon">🏢</span>
        <span class="office-name">その他</span>
    `;
    container.appendChild(otherPanel);

    // 初期化時に必ず1つ選択状態にする（selectOfficeで副作用も同期）
    if (officeList.length > 0) {
        selectOffice(officeList[0]);
    } else {
        selectOffice('other');
    }
}
// 事務所オプションをロード
async function loadOfficeOptions() {
    try {
        // office一覧とofficeMappingを並列取得
        const [officeRes, mappingRes] = await Promise.all([
            fetch('https://vtuber-335811-default-rtdb.firebaseio.com/office.json'),
            fetch('https://vtuber-335811-default-rtdb.firebaseio.com/officeMapping.json')
        ]);
        if (!officeRes.ok || !mappingRes.ok) throw new Error('事務所一覧またはMappingの取得に失敗しました');
        const officeRaw = await officeRes.json();
        window.officeRaw = officeRaw;
        console.log('[DEBUG] officeRaw:', officeRaw);
        // 日付やupdateTimeなど事務所名以外を除外
        const officeList = Object.values(officeRaw).filter(v => {
            if (typeof v !== 'string') return false;
            if (!v || v.trim() === '') return false;
            // updateTimeや日付形式（YYYY-MM-DD）を除外
            if (v.match(/updateTime/i)) return false;
            // YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD
            if (v.match(/^\d{4}[-\/\.]\d{2}[-\/\.]\d{2}$/)) return false;
            // YYYY-MM-DD HH:mm, YYYY/MM/DD HH:mm, YYYY.MM.DD HH:mm
            if (v.match(/^\d{4}[-\/\.]\d{2}[-\/\.]\d{2} \d{2}:\d{2}$/)) return false;
            // 数値のみ（例: 20250728）も除外
            if (v.match(/^\d{8}$/)) return false;
            return true;
        });
        window.officeList = officeList;
        console.log('[DEBUG] officeList:', officeList);
        const officeMapping = await mappingRes.json();
        window.officeMapping = officeMapping;
        console.log('[DEBUG] officeMapping:', officeMapping);
        // 追加: 個別に値を確認
        console.log('officeRaw direct:', window.officeRaw);
        console.log('officeList direct:', window.officeList);
        console.log('officeMapping direct:', window.officeMapping);
        if (officeList.length === 0 || typeof officeMapping !== 'object') throw new Error('事務所データが不正です');
        generateOfficeRadioButtons(officeList, officeMapping);

        // VTuber管理タブの事務所フィルタ用プルダウンも同じロジックで生成
        const filterSelect = document.getElementById('office-filter-select');
        if (filterSelect) {
            filterSelect.innerHTML = '';
            // 先頭に「全ての事務所（フィルタなし）」を追加
            const allOption = document.createElement('option');
            allOption.value = '';
            allOption.textContent = '全ての事務所';
            filterSelect.appendChild(allOption);
            // 事務所リストを追加
            officeList.forEach(office => {
                const key = office.trim();
                const displayName = officeMapping[key] || office;
                const option = document.createElement('option');
                option.value = office;
                option.textContent = displayName;
                filterSelect.appendChild(option);
            });
            // 初期表示時に全件表示
            filterSelect.addEventListener('change', searchVtubers);
            // 初期化時に一度全件表示
            setTimeout(() => { searchVtubers(); }, 0);
        }
    } catch (error) {
        console.error('Office取得エラー:', error);
        // 追加: catch直後に個別console.log
        console.log('catch error', error);
        console.log('catch window.officeRaw:', window.officeRaw);
        console.log('catch window.officeList:', window.officeList);
        console.log('catch window.officeMapping:', window.officeMapping);
        // 画面にも詳細データを表示
        let debugMsg = `<b>Office取得エラー:</b> ${error.message}<br>`;
        // contentElement未定義エラー回避: debugMsgの生成を安全に行う
        if (typeof window.officeRaw !== 'undefined') {
            debugMsg += `<b>officeRaw:</b> <pre>${JSON.stringify(window.officeRaw, null, 2)}</pre>`;
        }
        if (typeof window.officeList !== 'undefined') {
            debugMsg += `<b>officeList:</b> <pre>${JSON.stringify(window.officeList, null, 2)}</pre>`;
        }
        if (typeof window.officeMapping !== 'undefined') {
            debugMsg += `<b>officeMapping:</b> <pre>${JSON.stringify(window.officeMapping, null, 2)}</pre>`;
        }
        // contentElement未定義エラー回避: showStatusのみ使用
        showStatus(debugMsg, 'error');
        // フォールバック: デフォルト事務所
        const fallbackList = [
            'personal', 'hololive', 'holoEN', 'holoID', 'KizunaAI', 'holostars', 'nijisannji', '.LIVE', 'Vshojo', 'noripuro', 'nanashiinc', 'aogirigakuen', 'vsupo'
        ];
        const fallbackMapping = {
            KizunaAI: 'Kizuna AI', Vshojo: 'VShojo', aogirigakuen: 'あおぎり高校', dotLIVE: '.LIVE', holoEN: 'ホロライブEnglish', holoID: 'ホロライブインドネシア', hololive: 'ホロライブ', holostars: 'ホロスターズ', nanashiinc: 'ななしいんく', nijisannji: 'にじさんじ', noripuro: 'のりプロ', personal: '個人', vsupo: 'ぶいすぽっ'
        };
        generateOfficeRadioButtons(fallbackList, fallbackMapping);
    }
}
// // 初期化
// document.addEventListener('DOMContentLoaded', function() {
//     showStatus('🎮 VTuberデータ管理ツールへようこそ！', 'info');
//     loadOfficeOptions(); // ←これを追加
// });
// ログアウト機能
function logout() {
    sessionStorage.removeItem('adminUser');
    window.location.href = 'admin-login.html';
}
function initializeApp() {
    // 元の初期化コードをここに移動
    checkConnection();
    loadOfficeOptions();
    loadOfficeMappings();
}

// グローバル変数

// アプリケーション初期化
function initializeApp() {
    updateApiDisplay();
    showStatus('🎮 VTuberデータ管理ツールへようこそ！データの入稿機能が追加されました。', 'info');

    // Office選択肢を初期読み込み
    loadOfficeOptions();

    // 自動接続テスト
    setTimeout(() => {
        testConnection();
    }, 1000);
}

// ページ読み込み時に認証チェック
document.addEventListener('DOMContentLoaded', () => {
    if (checkAuthentication()) {
        // 認証済みの場合は初期化処理を実行
        initializeApp();
    }
});
window.loadOfficeOptions = loadOfficeOptions;






// 環境に応じてAPIベースURLを設定
function getApiBase() {
    // ローカルファイルの場合は本番環境を使用（一時的）
    if (location.protocol === 'file:') {
        // 本番環境を使用
        return 'https://us-central1-vtuber-335811.cloudfunctions.net';
    }
    // デプロイ済みの場合は本番環境
    return 'https://us-central1-vtuber-335811.cloudfunctions.net';
}

const API_BASE = getApiBase();

// 環境切り替え機能
let currentApiBase = getApiBase();

function switchToEmulator() {
    currentApiBase = 'http://localhost:5002/vtuber-335811/us-central1';
    updateApiDisplay();
    showStatus('🔧 Firebase Emulatorに切り替えました', 'info');
}

function switchToProduction() {
    currentApiBase = 'https://us-central1-vtuber-335811.cloudfunctions.net';
    updateApiDisplay();
    showStatus('🌐 本番環境に切り替えました', 'info');
}

function updateApiDisplay() {
    document.getElementById('apiUrl').textContent = currentApiBase;
}

// 接続テスト機能
async function testConnection() {
    try {
        showStatus('🔄 API接続をテスト中...', 'info');
        const response = await fetch(`${currentApiBase}/analyzeVtuberData`, {
            method: 'GET',
            mode: 'cors'
        });
        if (response.ok) {
            showStatus('✅ API接続成功', 'success');
            return true;
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        let errorMsg = `❌ API接続失敗: ${error.message}`;
        if (error.message.includes('Failed to fetch')) {
            errorMsg += '\n\n💡 解決方法:\n1. Firebase Emulatorを起動してください\n2. または本番環境を使用してください';
        }
        showStatus(errorMsg, 'error');
        return false;
    }
}

// 接続テスト機能
async function testConnection() {
    try {
        const response = await fetch(`${API_BASE}/analyzeVtuberData`);
        if (response.ok) {
            showStatus('✅ API接続成功', 'success');
            return true;
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        showStatus(`❌ API接続失敗: ${error.message}`, 'error');
        return false;
    }
}

// 全VTuberデータのキャッシュ
let allVtuberData = null;
let selectedOffice = null;
let availableOffices = {}; // Office一覧を保持

// サムネイル画像要素を作成（チャンネル名も取得）
function createThumbnailElement(channelId, vtuberName, callback) {
    const img = document.createElement('img');
    img.className = 'vtuber-thumbnail loading';
    img.alt = vtuberName;

    if (!channelId || channelId === 'なし') {
        // チャンネルIDがない場合はフォールバックアバターを生成
        img.src = generateFallbackAvatar(vtuberName);
        img.className = 'vtuber-thumbnail';
        if (callback) callback(null); // チャンネル名なし
        return img;
    }

    // 新しいgetYouTubeChannelInfo APIを使用してサムネイルを取得
    const fetchThumbnail = async () => {
        try {
            const response = await fetch(`${currentApiBase}/getYouTubeChannelInfo?channelIds=${channelId}`);
            if (response.ok) {
                const data = await response.json();
                if (data.success && data.channelInfo[channelId]) {
                    const channelData = data.channelInfo[channelId];
                    if (channelData.thumbnail) {
                        loadImageWithFallback(img, channelData.thumbnail, () => {
                            // APIから取得したサムネイルが失敗した場合のフォールバック
                            img.src = generateFallbackAvatar(vtuberName);
                            img.className = 'vtuber-thumbnail';
                        });
                        // チャンネル名をコールバックで返す
                        if (callback) callback(channelData.title);
                        return;
                    }
                }
            }
        } catch (error) {
            console.log('getYouTubeChannelInfo API failed:', error);
        }

        // API呼び出しが失敗した場合はフォールバックアバター
        img.src = generateFallbackAvatar(vtuberName);
        img.className = 'vtuber-thumbnail';
        if (callback) callback(null); // チャンネル名なし
    };

    // 非同期でサムネイル取得
    fetchThumbnail();

    return img;
}

// 画像読み込みとフォールバック処理
function loadImageWithFallback(imgElement, url, fallbackCallback) {
    imgElement.onload = () => {
        imgElement.className = 'vtuber-thumbnail';
    };

    imgElement.onerror = () => {
        fallbackCallback();
    };

    imgElement.src = url;
}

// フォールバックアバター生成
function generateFallbackAvatar(vtuberName) {
    let displayText = '';
    let bgColor = '';

    const colors = [
        '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57',
        '#FF9FF3', '#54A0FF', '#5F27CD', '#00D2D3', '#FF9F43',
        '#10AC84', '#EE5A6F', '#C44569', '#F8B500', '#6C5CE7'
    ];

    // VTuber名から数字を抽出（例: "VTuber 123" → "123"）
    const numberMatch = vtuberName.match(/VTuber\s+(\d+)/);
    if (numberMatch) {
        const number = numberMatch[1];
        displayText = number.length > 3 ? number.substring(0, 3) : number;
        // 数字をベースに色を決定
        const colorIndex = parseInt(number) % colors.length;
        bgColor = colors[colorIndex];
    } else {
        // VTuber形式でない場合は、名前の最初の文字を使用
        const firstChar = vtuberName.charAt(0).toUpperCase();
        displayText = firstChar;

        // VTuber名から色を決定（ハッシュベース）
        let hash = 0;
        for (let i = 0; i < vtuberName.length; i++) {
            hash = vtuberName.charCodeAt(i) + ((hash << 5) - hash);
        }
        const colorIndex = Math.abs(hash) % colors.length;
        bgColor = colors[colorIndex];
    }

    return `data:image/svg+xml,${encodeURIComponent(`
                <svg width="40" height="40" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="20" cy="20" r="20" fill="${bgColor}"/>
                    <text x="20" y="26" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="${displayText.length > 2 ? '12' : '16'}" font-weight="bold">${displayText}</text>
                </svg>
            `)}`;
}

// @ハンドル名からチャンネルIDを取得
async function convertHandleToChannelId(handle) {
    try {
        // @記号を除去
        const cleanHandle = handle.replace(/^@/, '');

        // 方法1: YouTube OEmbed APIを試行
        try {
            const oEmbedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/@${cleanHandle}&format=json`;
            const response = await fetch(oEmbedUrl);

            if (response.ok) {
                const data = await response.json();
                if (data.author_url) {
                    // author_urlからチャンネルIDを抽出
                    const channelMatch = data.author_url.match(/channel\/(UC[a-zA-Z0-9_-]{22})/);
                    if (channelMatch) {
                        return channelMatch[1];
                    }
                }
            }
        } catch (oembedError) {
            console.log('OEmbed method failed:', oembedError);
        }

        // 方法2: HTMLスクレイピング（プロキシ経由）
        try {
            const proxyUrl = `https://api.allorigins.win/get?url=${encodeURIComponent(`https://www.youtube.com/@${cleanHandle}`)}`;
            const response = await fetch(proxyUrl);
            const data = await response.json();

            if (data.contents) {
                // HTMLからチャンネルIDを抽出
                const patterns = [
                    /"channelId":"(UC[a-zA-Z0-9_-]{22})"/,
                    /channel\/(UC[a-zA-Z0-9_-]{22})/,
                    /"externalId":"(UC[a-zA-Z0-9_-]{22})"/,
                    /\/channel\/(UC[a-zA-Z0-9_-]{22})/g
                ];

                for (const pattern of patterns) {
                    const match = data.contents.match(pattern);
                    if (match) {
                        return match[1];
                    }
                }
            }
        } catch (scrapeError) {
            console.log('Scraping method failed:', scrapeError);
        }

        throw new Error('チャンネルIDが見つかりませんでした。@ハンドル名が正しいか確認してください。');

    } catch (error) {
        console.error('Handle to Channel ID conversion error:', error);
        throw error;
    }
}

// 手動変換ボタンの処理
async function manualConvertChannelId() {
    await validateAndConvertChannelId();
}

// チャンネルID/ハンドル名の検証と変換
async function validateAndConvertChannelId() {
    const input = document.getElementById('channelId');
    const statusDiv = document.getElementById('channelIdStatus');
    const value = input.value.trim();

    if (!value) {
        statusDiv.innerHTML = '';
        return;
    }

    // 既にチャンネルIDの形式の場合
    if (value.match(/^UC[a-zA-Z0-9_-]{22}$/)) {
        statusDiv.innerHTML = '<span style="color: green;">✅ 有効なチャンネルIDです</span>';
        return;
    }

    // @ハンドル名の場合（より柔軟な形式を受け入れ）
    if (value.match(/^@?[a-zA-Z0-9_.-]+$/) && !value.match(/^UC[a-zA-Z0-9_-]{22}$/)) {
        statusDiv.innerHTML = '<span style="color: blue;">🔄 @ハンドル名をチャンネルIDに変換中...</span>';

        try {
            const channelId = await convertHandleToChannelId(value);
            input.value = channelId;
            statusDiv.innerHTML = `<span style="color: green;">✅ 変換完了: ${channelId}</span>`;
        } catch (error) {
            statusDiv.innerHTML = `<span style="color: red;">❌ 変換失敗: ${error.message}<br>手動で正しいチャンネルIDを入力してください</span>`;
        }
        return;
    }

    // 無効な形式
    statusDiv.innerHTML = '<span style="color: red;">❌ 無効な形式です（チャンネルIDまたは@ハンドル名を入力してください）</span>';
}

function selectOffice(officeName) {
    selectedOffice = officeName;
    console.log('[selectOffice] 選択事務所:', officeName);

    // すべてのパネルの選択状態をリセット
    const allPanels = document.querySelectorAll('.office-panel-cute');
    console.log('[selectOffice] 全パネル数:', allPanels.length);
    allPanels.forEach((panel, idx) => {
        if (panel.classList.contains('selected')) {
            console.log(`[selectOffice] リセット前 selectedパネル[${idx}]:`, panel.getAttribute('data-office'));
        }
        panel.classList.remove('selected');
    });

    // 選択されたパネルを強調
    let selectedPanel = document.querySelector(`.office-panel-cute[data-office="${officeName}"]`);
    console.log('[selectOffice] 選択対象 selectedPanel:', selectedPanel);
    if (!selectedPanel) {
        selectedPanel = document.querySelector('.office-panel-cute');
        console.log('[selectOffice] フォールバック selectedPanel:', selectedPanel);
        if (selectedPanel) {
            selectedPanel.classList.add('selected');
            selectedOffice = selectedPanel.getAttribute('data-office');
        }
    } else {
        selectedPanel.classList.add('selected');
    }

    // 選択後の全パネルのselected状態を確認
    document.querySelectorAll('.office-panel-cute').forEach((panel, idx) => {
        if (panel.classList.contains('selected')) {
            console.log(`[selectOffice] 選択後 selectedパネル[${idx}]:`, panel.getAttribute('data-office'));
        }
    });

    // ここでgetSelectedOffice()を呼ぶと、selectedクラスが付与された直後なのでOK
    console.log('[selectOffice] getSelectedOffice():New', getSelectedOffice());

    // カスタム事務所名の表示/非表示
    toggleCustomOffice(selectedOffice);
    // 選択後のgetSelectedOffice()値を出力
    console.log('[selectOffice] getSelectedOffice():', getSelectedOffice());
    // キャッシュクリア＋一覧再取得（タブ位置保持用）
    refreshOfficeVtuberList(selectedOffice);
    // キャッシュクリア＋一覧再取得（selectedOfficeを使う）
    function refreshOfficeVtuberList(officeName) {
        clearVtuberDataCache();
        // officeNameが未指定なら現在のselectedOfficeを使う
        const office = officeName || selectedOffice;
        displayOfficeVtubers(office);
    }
}

// カスタム事務所名の表示/非表示
function toggleCustomOffice(office = null) {
    const officeName = office || document.querySelector('input[name="office"]:checked')?.value;
    const customGroup = document.getElementById('customOfficeGroup');
    const customOfficeKey = document.getElementById('customOfficeKey');
    const customOfficeDisplayName = document.getElementById('customOfficeDisplayName');

    if (officeName === 'other') {
        if (customGroup) customGroup.style.display = 'block';
        if (customOfficeKey) customOfficeKey.required = true;
        if (customOfficeDisplayName) customOfficeDisplayName.required = true;
    } else {
        if (customGroup) customGroup.style.display = 'none';
        if (customOfficeKey) {
            customOfficeKey.required = false;
            customOfficeKey.value = '';
        }
        if (customOfficeDisplayName) {
            customOfficeDisplayName.required = false;
            customOfficeDisplayName.value = '';
        }
    }
}

// VTuberデータを取得（キャッシュ機能付き）
async function fetchAllVtuberData() {
    // キャッシュ機能を一時的に無効化（常にAPIから取得）
    allVtuberData = null;
    try {
        console.log('Fetching VTuber data from:', `${currentApiBase}/exportVtuberData?format=json`);
        const response = await fetch(`${currentApiBase}/exportVtuberData?format=json`);
        const result = await response.json();

        console.log('Fetch result:', result);

        if (result.success) {
            allVtuberData = result.data;
            console.log('VTuber data loaded:', Object.keys(allVtuberData).length, 'entries');
            return allVtuberData;
        } else {
            throw new Error(result.message || 'データの取得に失敗しました');
        }
    } catch (error) {
        console.error('VTuber data fetch error:', error);
        return null;
    }
}

// 数値を考慮した自然ソート関数
function naturalSort(a, b) {
    const aName = a.name || '';
    const bName = b.name || '';

    // 「VTuber 数字」のパターンをチェック
    const aMatch = aName.match(/^VTuber\s+(\d+)$/);
    const bMatch = bName.match(/^VTuber\s+(\d+)$/);

    // 両方ともVTuber形式の場合は数値で比較
    if (aMatch && bMatch) {
        return parseInt(aMatch[1]) - parseInt(bMatch[1]);
    }

    // 片方だけVTuber形式の場合
    if (aMatch && !bMatch) return 1;  // VTuber形式を後に
    if (!aMatch && bMatch) return -1; // VTuber形式を後に

    // 通常の文字列比較
    return aName.localeCompare(bName, 'ja', { numeric: true });
}

// 選択した事務所のVTuber一覧を表示
async function displayOfficeVtubers(officeName) {
    const listContainer = document.getElementById('officeVtuberList');
    const titleElement = document.getElementById('officeListTitle');
    const contentElement = document.getElementById('vtuberListContent');

    // ローディング表示
    contentElement.innerHTML = '<div class="loading-spinner"></div> データを読み込み中...';
    listContainer.style.display = 'block';

    // 表示名を設定
    const displayName = officeName === 'personal' ? '個人勢' :
        officeName === 'other' ? 'カスタム事務所' : officeName;
    titleElement.textContent = `${displayName}のVTuber一覧`;

    const vtuberData = await fetchAllVtuberData();
    if (!vtuberData) {
        contentElement.innerHTML = '<div class="vtuber-list-empty">❌ データの取得に失敗しました</div>';
        return;
    }

    // VTuberデータを正規化
    let vtuberList = [];
    if (Array.isArray(vtuberData)) {
        vtuberList = vtuberData;
    } else if (vtuberData.vtuberDataList && Array.isArray(vtuberData.vtuberDataList)) {
        vtuberList = vtuberData.vtuberDataList;
    } else if (typeof vtuberData === 'object') {
        // vtuberDataListキーがなければ全値をリスト化（値がobjectでofficeプロパティを持つもののみ）
        vtuberList = Object.values(vtuberData).filter(v => v && typeof v === 'object' && v.office);
    }

    // 選択した事務所でフィルタ
    const filtered = vtuberList.filter(v => v.office === officeName);

    if (filtered.length === 0) {
        contentElement.innerHTML = '<div class="vtuber-list-empty">この事務所のVTuberは登録されていません</div>';
        return;
    }

    // VTuber一覧表示は displayVtuberList() に統一
    // ...existing code...
}
// ...不要な重複・スコープ外コードを削除...

// データキャッシュをクリア（新しいVTuberが追加された時に呼び出す）
function clearVtuberDataCache() {
    allVtuberData = null;
    allRegisteredVtubers = [];
    filteredVtubers = [];
}

// タブ切り替え
function switchTab(tabName, event) {
    // すべてのタブコンテンツを非表示
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.style.display = 'none';
        tab.classList.remove('active');
    });
    // すべてのタブボタンを非アクティブ
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.classList.remove('active');
    });
    // 選択されたタブを表示
    const tabContent = document.getElementById(tabName + '-tab');
    if (tabContent) {
        tabContent.style.display = 'block';
        tabContent.classList.add('active');
    }
    // タブボタンにactiveを付与
    if (event && event.target) {
        event.target.classList.add('active');
    } else {
        // eventがない場合はdata-tab属性で該当ボタンを探す
        const btn = document.querySelector('.tab-button[data-tab="' + tabName + '"]');
        if (btn) btn.classList.add('active');
    }
    // Office管理タブの場合はOffice Mappingを読み込み
    if (tabName === 'office') {
        loadOfficeMapping();
    }
    // Add New VTuberタブの場合はOffice選択肢を読み込み
    if (tabName === 'add') {
        loadOfficeOptions();
    }
    // Auto Discoverタブの場合は既存VTuberリストを読み込み
    if (tabName === 'discover') {
        loadVtubersForSeed();
    }
    // VTuber管理タブの場合は登録済みVTuber一覧を読み込み
    if (tabName === 'manage') {
        loadRegisteredVtubers();
    }
}

function searchVtubers() {
    // 入力値取得
    const searchInput = document.getElementById('vtuberSearchInput');
    const filterSelect = document.getElementById('office-filter-select');
    const keyword = searchInput ? searchInput.value.trim() : '';
    const office = filterSelect ? filterSelect.value : '';
    // VTuber一覧データ取得（キャッシュ or API）
    fetchAllVtuberData().then(vtuberData => {
        if (!vtuberData) return;
        let vtuberList = [];
        if (Array.isArray(vtuberData)) {
            vtuberList = vtuberData;
        } else if (vtuberData.vtuberDataList && Array.isArray(vtuberData.vtuberDataList)) {
            vtuberList = vtuberData.vtuberDataList;
        } else if (typeof vtuberData === 'object') {
            vtuberList = Object.values(vtuberData).filter(v => v && typeof v === 'object' && v.office);
        }
        // 事務所フィルタ
        let filtered = vtuberList;
        if (office) {
            filtered = filtered.filter(v => v.office === office);
        }
        // キーワードフィルタ
        if (keyword) {
            filtered = filtered.filter(v => {
                return (v.name && v.name.includes(keyword)) ||
                    (v.channelId && v.channelId.includes(keyword));
            });
        }
        // 一覧表示
        displayVtuberList(filtered);
    });
}
window.searchVtubers = searchVtubers;

// VTuber一覧をテーブルで表示（最低限の実装）
function displayVtuberList(vtubers) {
    const container = document.getElementById('vtuberListContainer');
    if (!container) return;
    if (!vtubers || vtubers.length === 0) {
        container.innerHTML = '<div class="vtuber-list-empty">該当するVTuberがいません</div>';
        document.getElementById('displayedVtuberCount').textContent = 0;
        document.getElementById('totalVtuberCount').textContent = 0;
        return;
    }
    // テーブル生成
    let html = '<table class="vtuber-table"><thead><tr>' +
        '<th>No</th><th>名前</th><th>チャンネルID</th><th>事務所</th><th>誕生日</th>' +
        '</tr></thead><tbody>';
    vtubers.forEach((v, i) => {
        html += `<tr><td>${i + 1}</td><td>${v.name || ''}</td><td>${v.channelId || ''}</td><td>${v.office || ''}</td><td>${v.birthday || ''}</td></tr>`;
    });
    html += '</tbody></table>';
    container.innerHTML = html;
    document.getElementById('displayedVtuberCount').textContent = vtubers.length;
    document.getElementById('totalVtuberCount').textContent = vtubers.length;
}

// ...Office管理・VTuber追加・重複チェック・Auto Discover等の関数はvtuber-data-manager-new.jsに集約...

// データエクスポート
async function exportData(format) {
    try {
        showStatus('📊 データをエクスポートしています...', 'info');
        showProgress(true, 30);

        const response = await fetch(`${currentApiBase}/exportVtuberData?format=${format}`);
        const result = await response.json();

        if (result.success) {
            let filename, content, mimeType;

            if (format === 'csv') {
                filename = `vtuber-data-${new Date().toISOString().split('T')[0]}.csv`;
                content = result.csvData;
                mimeType = 'text/csv';
            } else if (format === 'template') {
                filename = `vtuber-template-${new Date().toISOString().split('T')[0]}.csv`;
                content = result.csvData;
                mimeType = 'text/csv';
            } else {
                filename = `vtuber-data-${new Date().toISOString().split('T')[0]}.json`;
                content = JSON.stringify(result.data, null, 2);
                mimeType = 'application/json';
            }

            // ファイルダウンロード
            const blob = new Blob([content], { type: mimeType });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);

            showStatus(`✅ ${filename} をダウンロードしました (${result.totalRecords}件)`, 'success');
            showProgress(false);
        } else {
            throw new Error(result.message || 'エクスポートに失敗しました');
        }
    } catch (error) {
        console.error('Export error:', error);
        showStatus(`❌ エクスポートエラー: ${error.message}`, 'error');
        showProgress(false);
    }
}

// ファイルアップロード処理
function handleFileUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function (e) {
        document.getElementById('importData').value = e.target.result;
        showStatus(`📄 ファイル "${file.name}" を読み込みました`, 'success');
    };
    reader.readAsText(file);
}

// データインポート
async function importVtuberData() {
    try {
        const data = document.getElementById('importData').value.trim();
        const mode = document.getElementById('importMode').value;

        if (!data) {
            showStatus('❌ インポートするデータが入力されていません', 'error');
            return;
        }

        showStatus(`🔄 データを${mode === 'validate' ? '検証' : 'インポート'}しています...`, 'info');
        showProgress(true, 30);

        const response = await fetch(`${currentApiBase}/importVtuberData`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: data,
                mode: mode
            })
        });

        const result = await response.json();
        showProgress(true, 80);

        if (result.success) {
            if (mode === 'validate') {
                showStatus(`✅ 検証完了: ${result.validatedCount}件のデータを検証しました`, 'success');
            } else {
                showStatus(`✅ インポート完了: ${result.importedCount}件のデータを${mode === 'replace' ? '置換' : '統合'}しました`, 'success');
            }
        } else {
            throw new Error(result.message || 'インポートに失敗しました');
        }

        showProgress(false);

    } catch (error) {
        console.error('Import error:', error);
        showStatus(`❌ ${document.getElementById('importMode').value === 'validate' ? '検証' : 'インポート'}エラー: ${error.message}`, 'error');
        showProgress(false);
    }
}

// ===========================================
// 新しい一括登録機能
// ===========================================

let currentAddMode = 'single';
let bulkEntryCounter = 0;
let existingVtuberData = new Set(); // 既存データキャッシュ
let existingVtuberList = []; // Auto Discover用の既存データ配列
let duplicateCheckTimeout = null;

// 追加モード切り替え
function switchAddMode(mode) {
    currentAddMode = mode;
    // タブボタンの見た目を更新
    document.querySelectorAll('.tab-switch-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    if (mode === 'single') {
        document.querySelector('.tab-switch-btn[onclick*="single"]').classList.add('active');
    } else {
        document.querySelector('.tab-switch-btn[onclick*="bulk"]').classList.add('active');
    }
    // モードに応じて表示切り替え
    document.getElementById('single-mode').style.display = mode === 'single' ? 'block' : 'none';
    document.getElementById('bulk-mode').style.display = mode === 'bulk' ? 'block' : 'none';
    if (mode === 'bulk' && document.getElementById('bulk-entries').children.length === 0) {
        // 一括モードで初回の場合は3つのエントリを自動生成
        addNewEntry();
        addNewEntry();
        addNewEntry();
    }
}

// 既存VTuberデータを取得してキャッシュ
async function loadExistingVtuberData() {
    try {
        const response = await fetch(`${currentApiBase}/exportVtuberData?format=json`);
        const result = await response.json();

        console.log('既存データ取得レスポンス:', result);

        if (result.success) {
            existingVtuberData.clear();

            // データ形式を適切に処理
            let vtuberArray = [];

            if (Array.isArray(result.data)) {
                vtuberArray = result.data;
                console.log('既存データ: 配列形式', vtuberArray.length, '件');
            } else if (result.data && typeof result.data === 'object') {
                // 数値キーのオブジェクト形式の場合
                vtuberArray = Object.values(result.data).filter(item => {
                    // nullやundefinedでないオブジェクトのみを取得
                    return item && typeof item === 'object';
                });
            } // ←ここでelse ifブロックを閉じる

            vtuberArray.forEach((vtuber, index) => {
                if (vtuber && typeof vtuber === 'object') {
                    // チャンネルID、名前、Twitter名での重複をチェック
                    if (vtuber.channelId) existingVtuberData.add(`channel:${vtuber.channelId.toLowerCase()}`);
                    if (vtuber.twitterName) existingVtuberData.add(`twitter:${vtuber.twitterName.toLowerCase()}`);
                    if (vtuber.name) existingVtuberData.add(`name:${vtuber.name.toLowerCase()}`);
                } else {
                    console.warn('Invalid vtuber data at index:', index, vtuber);
                }
            });
            console.log('📊 既存データキャッシュ完了:', existingVtuberData.size, '件, 配列長:', vtuberArray.length);
        }
    } catch (error) {
        console.error('既存データ読み込みエラー:', error);
        existingVtuberList = []; // エラー時は空配列
    }
}

// @Handle をチャンネルIDに変換
async function convertHandleToChannelId(handle) {
    if (!handle.startsWith('@')) return handle;

    try {
        const response = await fetch(`${currentApiBase}/getYouTubeChannelInfo`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ handle: handle })
        });
        const result = await response.json();

        if (result.success && result.channelId) {
            return result.channelId;
        }
    } catch (error) {
        console.error('@Handle変換エラー:', error);
    }
    return handle; // 変換失敗時は元の値を返す
}

// リアルタイム重複チェック
async function checkDuplicates(mode) {
    // デバウンス処理
    if (duplicateCheckTimeout) {
        clearTimeout(duplicateCheckTimeout);
    }

    duplicateCheckTimeout = setTimeout(async () => {
        if (mode === 'single') {
            await checkSingleDuplicates();
        } else {
            await checkBulkDuplicates();
        }
    }, 500);
}

async function checkSingleDuplicates() {
    const name = document.getElementById('vtuberName').value.trim();
    const channelId = document.getElementById('channelId').value.trim();
    const twitterName = document.getElementById('twitterName').value.trim();

    let duplicates = [];

    if (name && existingVtuberData.has(`name:${name.toLowerCase()}`)) {
        duplicates.push('名前');
    }
    if (channelId && existingVtuberData.has(`channel:${channelId.toLowerCase()}`)) {
        duplicates.push('チャンネルID');
    }
    if (twitterName && existingVtuberData.has(`twitter:${twitterName.toLowerCase()}`)) {
        duplicates.push('Twitter名');
    }

    // ステータス表示更新
    updateSingleStatus('singleNameStatus', name && !existingVtuberData.has(`name:${name.toLowerCase()}`), '名前');
    updateSingleStatus('singleChannelStatus', channelId && !existingVtuberData.has(`channel:${channelId.toLowerCase()}`), 'チャンネルID');
    updateSingleStatus('singleTwitterStatus', !twitterName || !existingVtuberData.has(`twitter:${twitterName.toLowerCase()}`), 'Twitter名');

    // 登録ボタンの状態更新
    const addBtn = document.getElementById('singleAddBtn');
    addBtn.disabled = duplicates.length > 0 || !name || !channelId;
}

function updateSingleStatus(elementId, isValid, fieldName) {
    const element = document.getElementById(elementId);
    if (!element) return;

    if (isValid) {
        element.innerHTML = `<span style="color: #28a745;">✓ ${fieldName}は利用可能です</span>`;
    } else {
        element.innerHTML = `<span style="color: #dc3545;">× ${fieldName}は既に登録されています</span>`;
    }
}

// 新しいエントリを追加
function addNewEntry() {
    const bulkEntries = document.getElementById('bulk-entries');
    const entryId = `entry-${++bulkEntryCounter}`;
    // テンプレートから複製
    const template = document.getElementById('bulk-entry-template');
    const clone = template.content.cloneNode(true);
    // 各inputにユニークIDを付与
    const form = clone.querySelector('form');
    form.id = entryId;
    form.setAttribute('data-entry-id', entryId);
    // 名前・チャンネル・twitter・birthday
    const fields = form.querySelectorAll('[data-field]');
    fields.forEach(field => {
        const base = field.getAttribute('data-field');
        field.id = `${entryId}-${base}`;
        // 重複チェックイベント
        if (base === 'name' || base === 'channel' || base === 'twitter') {
            field.setAttribute('oninput', `checkEntryDuplicates('${entryId}')`);
        }
    });
    // officeFlgラジオのname属性をユニーク化
    const officeFlgRadios = form.querySelectorAll('input[type="radio"][name="officeFlg"]');
    officeFlgRadios.forEach(radio => {
        radio.name = `${entryId}-officeFlg`;
    });
    // 削除ボタン
    const removeBtn = form.querySelector('.btn-remove');
    if (removeBtn) removeBtn.setAttribute('onclick', `removeEntry('${entryId}')`);
    // ステータスID
    const statusDiv = form.querySelector('.status-indicator');
    if (statusDiv) statusDiv.id = `${entryId}-status`;
    bulkEntries.appendChild(clone);
    updateBulkStats();
}

// エントリ削除
function removeEntry(entryId) {
    const entry = document.getElementById(entryId);
    if (entry) {
        entry.remove();
        updateBulkStats();
    }
}

// 全エントリクリア
function clearAllEntries() {
    if (confirm('全てのエントリをクリアしますか？')) {
        document.getElementById('bulk-entries').innerHTML = '';
        updateBulkStats();
    }
}

// エントリごとの重複チェック
async function checkEntryDuplicates(entryId) {
    const entry = document.getElementById(entryId);
    if (!entry) return;

    const statusIndicator = document.getElementById(`${entryId}-status`);
    const nameInput = entry.querySelector('[data-field="name"]');
    const channelInput = entry.querySelector('[data-field="channel"]');
    const twitterInput = entry.querySelector('[data-field="twitter"]');

    const name = nameInput.value.trim();
    const channel = channelInput.value.trim();
    const twitter = twitterInput.value.trim();

    // 必須フィールドチェック
    if (!name || !channel) {
        statusIndicator.className = 'status-indicator status-checking';
        statusIndicator.textContent = '?';
        entry.classList.remove('duplicate', 'valid');
        updateBulkStats();
        return;
    }

    // 重複チェック
    let isDuplicate = false;
    let duplicateFields = [];

    if (existingVtuberData.has(`name:${name.toLowerCase()}`)) {
        isDuplicate = true;
        duplicateFields.push('名前');
    }
    if (existingVtuberData.has(`channel:${channel.toLowerCase()}`)) {
        isDuplicate = true;
        duplicateFields.push('チャンネルID');
    }
    if (twitter && existingVtuberData.has(`twitter:${twitter.toLowerCase()}`)) {
        isDuplicate = true;
        duplicateFields.push('Twitter名');
    }

    // ステータス更新
    if (isDuplicate) {
        statusIndicator.className = 'status-indicator status-duplicate';
        statusIndicator.textContent = '×';
        statusIndicator.title = `重複: ${duplicateFields.join(', ')}`;
        entry.classList.add('duplicate');
        entry.classList.remove('valid');
    } else {
        statusIndicator.className = 'status-indicator status-valid';
        statusIndicator.textContent = '✓';
        statusIndicator.title = '登録可能';
        entry.classList.add('valid');
        entry.classList.remove('duplicate');
    }

    updateBulkStats();
}

// 統計更新
function updateBulkStats() {
    const entries = document.querySelectorAll('.vtuber-entry');
    let validCount = 0;
    let duplicateCount = 0;
    let checkingCount = 0;

    entries.forEach(entry => {
        if (entry.classList.contains('valid')) {
            validCount++;
        } else if (entry.classList.contains('duplicate')) {
            duplicateCount++;
        } else {
            checkingCount++;
        }
    });

    document.getElementById('validCount').textContent = validCount;
    document.getElementById('duplicateCount').textContent = duplicateCount;
    document.getElementById('checkingCount').textContent = checkingCount;

    // 一括登録ボタンの状態更新
    const bulkAddBtn = document.getElementById('bulkAddBtn');
    bulkAddBtn.disabled = validCount === 0 || duplicateCount > 0;
}

// 一括登録実行
async function bulkAddVtubers() {
    const selectedOffice = getSelectedOffice();
    if (!selectedOffice) {
        showStatus('❌ 事務所を選択してください', 'error');
        return;
    }

    const validEntries = document.querySelectorAll('.vtuber-entry.valid');
    if (validEntries.length === 0) {
        showStatus('❌ 登録可能なエントリがありません', 'error');
        return;
    }

    const bulkAddBtn = document.getElementById('bulkAddBtn');
    bulkAddBtn.disabled = true;
    bulkAddBtn.textContent = '登録中...';

    try {
        showStatus(`📤 ${validEntries.length}件のVTuberを一括登録中...`, 'info');

        const results = [];
        let successCount = 0;
        let errorCount = 0;

        // 各エントリを順番に処理
        for (let i = 0; i < validEntries.length; i++) {
            const entry = validEntries[i];
            const nameInput = entry.querySelector('[data-field="name"]');
            const channelInput = entry.querySelector('[data-field="channel"]');
            const twitterInput = entry.querySelector('[data-field="twitter"]');
            const birthdayInput = entry.querySelector('[data-field="birthday"]');
            // officeFlgラジオ取得
            const officeFlgRadio = entry.querySelector('input[type="radio"][name$="officeFlg"]:checked');
            const birthdayValue = birthdayInput.value.trim();
            // MM-DD形式または-バリデーション
            if (!(birthdayValue === '-' || /^\d{2}[-\/]\d{2}$/.test(birthdayValue))) {
                showStatus(`❌ 誕生日は MM-DD 形式または「-」で入力してください: ${nameInput.value}`, 'error');
                continue;
            }
            if (!officeFlgRadio) {
                showStatus(`❌ 事務所所属フラグ（officeFlg）は必須です: ${nameInput.value}`, 'error');
                continue;
            }
            const debutInput = entry.querySelector('[data-field="debut"]');
            const debutValue = debutInput ? debutInput.value.trim() : '';
            let channeID = channelInput.value.trim();
            if (channeID.startsWith('@')) {
                channeID = await convertHandleToChannelId(channeID);
            }
            const vtuberData = {
                name: nameInput.value.trim(),
                channeID: channeID, // ← channeIDで送信
                twitterName: twitterInput.value.trim(),
                birthday: birthdayValue,
                office: selectedOffice,
                officeFlg: officeFlgRadio.value === 'true',
                debut: debutValue // 空でも必ず送信
            };
            // @Handleの場合は自動変換
            if (vtuberData.channeID.startsWith('@')) {
                const convertedId = await convertHandleToChannelId(vtuberData.channeID);
                vtuberData.channeID = convertedId;
            }
            try {
                const response = await fetch(`${currentApiBase}/addVtuberData`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(vtuberData)
                });
                const result = await response.json();
                if (result.success) {
                    successCount++;
                    entry.remove();
                } else {
                    errorCount++;
                    results.push(`❌ ${vtuberData.name}: ${result.error || '登録失敗'}`);
                }
            } catch (error) {
                errorCount++;
                results.push(`❌ ${vtuberData.name}: ${error.message}`);
            }
            showStatus(`📤 一括登録中... (${i + 1}/${validEntries.length})`, 'info');
        }

        // 結果表示
        let statusMessage = `✅ 一括登録完了! 成功: ${successCount}件`;
        if (errorCount > 0) {
            statusMessage += `, エラー: ${errorCount}件`;
        }

        showStatus(statusMessage, successCount > 0 ? 'success' : 'error');

        if (results.length > 0) {
            document.getElementById('addResult').innerHTML = `
                        <h3>詳細結果</h3>
                        <div style="max-height: 200px; overflow-y: auto; background: #f8f9fa; padding: 15px; border-radius: 4px;">
                            ${results.join('<br>')}
                        </div>
                    `;
            document.getElementById('addResult').style.display = 'block';
        }

        // 既存データキャッシュを更新
        await loadExistingVtuberData();
        updateBulkStats();

    } catch (error) {
        console.error('一括登録エラー:', error);
        showStatus(`❌ 一括登録エラー: ${error.message}`, 'error');
    } finally {
        bulkAddBtn.disabled = false;
        bulkAddBtn.textContent = '一括登録実行';
    }
}


// Auto Discover機能

// 発見モード切り替え
function switchDiscoverMode(mode) {
    // すべての発見モードを非表示
    document.querySelectorAll('.discover-mode').forEach(div => div.style.display = 'none');

    // すべてのタブスイッチボタンを非アクティブ
    document.querySelectorAll('.tab-switch-btn').forEach(btn => btn.classList.remove('active'));

    // 選択されたモードを表示
    document.getElementById(mode + '-discover').style.display = 'block';
    event.target.classList.add('active');
}

// 事務所名に基づくキーワード自動設定
function updateOfficeKeyword() {
    const office = document.getElementById('targetOffice').value;
    const keywordInput = document.getElementById('officeKeyword');

    const officeKeywords = {
        'hololive': 'hololive VTuber',
        'nijisanji': 'にじさんじ VTuber',
        'vspo': 'VSPO VTuber',
        'animare': 'あにまーれ VTuber',
        'reaction': 'りあくと VTuber',
        'honeystrap': 'ハニーストラップ VTuber'
    };

    keywordInput.value = officeKeywords[office] || office + ' VTuber';
}

// 関連チャンネル用のVTuberリスト読み込み
async function loadVtubersForSeed() {
    try {
        const response = await fetch(`${currentApiBase}/getFirebaseVtuberData`);
        const data = await response.json();

        console.log('VTuberデータ取得:', data);

        // データ形式を適切に処理
        let vtubers = [];

        if (Array.isArray(data)) {
            vtubers = data;
            console.log('Seed VTuber: 配列形式', vtubers.length, '件');
        } else if (data && typeof data === 'object') {
            if (data.success && data.data) {
                if (Array.isArray(data.data)) {
                    vtubers = data.data;
                    console.log('Seed VTuber: success配列形式', vtubers.length, '件');
                } else if (data.data && typeof data.data === 'object') {
                    // 数値キーのオブジェクト形式の場合
                    vtubers = Object.values(data.data).filter(item => {
                        return item && typeof item === 'object';
                    }).map(item => {
                        // データ構造の統一化
                        return {
                            name: item.name || `VTuber ${Object.keys(data.data).find(key => data.data[key] === item) || 'Unknown'}`,
                            channelId: item.channelId || item.channeID || 'N/A',
                            office: item.office || 'personal'
                        };
                    });
                    console.log('Seed VTuber: successオブジェクト形式', vtubers.length, '件');
                } else {
                    console.warn('Seed VTuber: 予期しないdata.data形式:', typeof data.data);
                    vtubers = [];
                }
            } else {
                // 直接オブジェクトの場合はvaluesを取得
                vtubers = Object.values(data).filter(item => {
                    return item && typeof item === 'object';
                });
                console.log('Seed VTuber: 直接オブジェクト形式', vtubers.length, '件');
            }
        } else {
            console.warn('Seed VTuber: 予期しないデータ形式:', typeof data);
            vtubers = [];
        }

        console.log('Processed vtubers for seed:', vtubers.length, 'items');

        const seedSelect = document.getElementById('seedVtuber');
        if (!seedSelect) {
            console.error('seedVtuber select element not found');
            return;
        }

        seedSelect.innerHTML = '<option value="">VTuberを選択...</option>';

        vtubers.forEach((vtuber, index) => {
            if (vtuber && (vtuber.name || vtuber.channelId)) {
                const option = document.createElement('option');
                option.value = vtuber.channelId || vtuber.id || `vtuber_${index}`;
                option.textContent = (vtuber.name || 'Unknown') + (vtuber.office ? ` (${vtuber.office})` : '');
                seedSelect.appendChild(option);
            }
        });

        console.log('Seed select populated with', seedSelect.options.length - 1, 'VTubers');
    } catch (error) {
        console.error('VTuberリストの読み込みエラー:', error);
        const seedSelect = document.getElementById('seedVtuber');
        if (seedSelect) {
            seedSelect.innerHTML = '<option value="">エラー: データを読み込めませんでした</option>';
        }
    }
}

// 人気順VTuber発見
async function discoverTrending() {
    const keyword = document.getElementById('trendingKeyword').value.trim();
    const order = document.getElementById('trendingOrder').value;
    const maxResults = parseInt(document.getElementById('trendingMaxResults').value);

    if (!keyword) {
        alert('検索キーワードを入力してください');
        return;
    }

    showDiscoverResults();
    resetDiscoverStats();

    try {
        const response = await fetch(`${currentApiBase}/discoverVtubers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                mode: 'trending',
                keyword: keyword,
                order: order,
                maxResults: maxResults
            })
        });

        const result = await response.json();
        displayDiscoveredVtubers(result.vtubers);

    } catch (error) {
        console.error('VTuber発見エラー:', error);
        alert('VTuberの発見中にエラーが発生しました: ' + error.message);
    }
}

// 事務所別VTuber発見
async function discoverByOffice() {
    const office = document.getElementById('targetOffice').value;
    const keyword = document.getElementById('officeKeyword').value.trim();

    if (!office) {
        alert('対象事務所を選択してください');
        return;
    }

    if (!keyword) {
        alert('検索キーワードを入力してください');
        return;
    }

    showDiscoverResults();
    resetDiscoverStats();

    try {
        const response = await fetch(`${currentApiBase}/discoverVtubers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                mode: 'office',
                office: office,
                keyword: keyword
            })
        });

        const result = await response.json();
        displayDiscoveredVtubers(result.vtubers);

    } catch (error) {
        console.error('事務所別VTuber発見エラー:', error);
        alert('事務所別VTuber発見中にエラーが発生しました: ' + error.message);
    }
}

// 関連チャンネル発見
async function discoverRelated() {
    const seedChannelId = document.getElementById('seedVtuber').value;
    const maxResults = parseInt(document.getElementById('relatedMaxResults').value);

    if (!seedChannelId) {
        alert('基準となるVTuberを選択してください');
        return;
    }

    showDiscoverResults();
    resetDiscoverStats();

    try {
        const response = await fetch(`${currentApiBase}/discoverVtubers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                mode: 'related',
                seedChannelId: seedChannelId,
                maxResults: maxResults
            })
        });

        const result = await response.json();
        displayDiscoveredVtubers(result.vtubers);

    } catch (error) {
        console.error('関連VTuber発見エラー:', error);
        alert('関連VTuber発見中にエラーが発生しました: ' + error.message);
    }
}

// 発見結果表示
function showDiscoverResults() {
    document.getElementById('discover-results').style.display = 'block';
    document.getElementById('discovered-vtubers').innerHTML = '<div class="loading">🔍 VTuber発見中...</div>';
}

// 発見統計リセット
function resetDiscoverStats() {
    document.getElementById('newVtuberCount').textContent = '0';
    document.getElementById('existingVtuberCount').textContent = '0';
    document.getElementById('analyzingCount').textContent = '0';
}

// 利用可能なOffice一覧を取得
async function loadAvailableOffices() {
    try {
        const response = await fetch(`${currentApiBase}/getOfficeMapping`);
        const result = await response.json();
        if (result.success) {
            availableOffices = result.officeMapping;
        } else {
            availableOffices = {};
        }
    } catch (error) {
        console.error('Office一覧取得エラー:', error);
        availableOffices = {};
    }
}

// Office選択肢のHTMLを生成
function generateOfficeOptions(currentOffice = '') {
    let options = '<option value="">選択してください</option>';
    options += '<option value="personal"' + (currentOffice === 'personal' ? ' selected' : '') + '>個人</option>';

    // 登録済みOffice一覧を追加
    for (const [key, displayName] of Object.entries(availableOffices)) {
        if (key !== 'personal') {
            const selected = currentOffice === key ? ' selected' : '';
            options += `<option value="${key}"${selected}>${displayName}</option>`;
        }
    }

    options += '<option value="other">その他</option>';
    return options;
}

// 発見されたVTuber表示
async function displayDiscoveredVtubers(vtubers) {
    const container = document.getElementById('discovered-vtubers');
    container.innerHTML = '';

    // Office一覧を取得
    await loadAvailableOffices();

    let newCount = 0;
    let existingCount = 0;

    for (const vtuber of vtubers) {
        const vtuberDiv = document.createElement('div');
        vtuberDiv.className = 'vtuber-item';

        // 既存チェック
        const isExisting = existingVtuberList.some(existing =>
            existing.channelId === vtuber.channelId ||
            existing.name === vtuber.name
        );

        if (isExisting) {
            existingCount++;
            vtuberDiv.classList.add('duplicate');
        } else {
            newCount++;
            vtuberDiv.classList.add('new');
        }

        vtuberDiv.innerHTML = `
                    <div class="vtuber-item-header">
                        <input type="checkbox" ${isExisting ? 'disabled' : 'checked'} 
                               data-channel-id="${vtuber.channelId}" class="vtuber-select">
                        <div class="vtuber-info">
                            <img src="${vtuber.thumbnailUrl || '/images/noImage200200.png'}" 
                                 alt="${vtuber.name}" class="vtuber-thumbnail">
                            <div class="vtuber-details">
                                <div class="vtuber-name">${vtuber.name}</div>
                                <div class="vtuber-meta">
                                    <span class="subscriber-count">👥 ${vtuber.subscriberCount?.toLocaleString() || 'N/A'}</span>
                                    <span class="video-count">📹 ${vtuber.videoCount?.toLocaleString() || 'N/A'}</span>
                                    ${vtuber.office ? `<span class="office-tag">${vtuber.office}</span>` : ''}
                                </div>
                                <div class="channel-id">ID: ${vtuber.channelId}</div>
                                <div class="twitter-input-group">
                                    <label>Twitter名:</label>
                                    <input type="text" class="twitter-input" placeholder="@なしのTwitterID" 
                                           data-channel-id="${vtuber.channelId}" ${isExisting ? 'disabled' : ''}>
                                </div>
                                <div class="office-input-group">
                                    <label>所属事務所:</label>
                                    <select class="office-select" data-channel-id="${vtuber.channelId}" ${isExisting ? 'disabled' : ''}>
                                        ${generateOfficeOptions(vtuber.office)}
                                    </select>
                                </div>
                                ${vtuber.description ? `<div class="vtuber-description">${vtuber.description.substring(0, 100)}...</div>` : ''}
                            </div>
                        </div>
                        <div class="status-indicator ${isExisting ? 'status-duplicate' : 'status-valid'}">
                            ${isExisting ? '既存' : '新規'}
                        </div>
                    </div>
                `;

        container.appendChild(vtuberDiv);
    }

    // 統計更新
    document.getElementById('newVtuberCount').textContent = newCount;
    document.getElementById('existingVtuberCount').textContent = existingCount;
    document.getElementById('analyzingCount').textContent = '0';
}

// 新規全選択
function selectAllNew() {
    document.querySelectorAll('.vtuber-item.new input[type="checkbox"]').forEach(checkbox => {
        checkbox.checked = true;
    });
}

// 全選択解除
function deselectAll() {
    document.querySelectorAll('.vtuber-item input[type="checkbox"]').forEach(checkbox => {
        if (!checkbox.disabled) {
            checkbox.checked = false;
        }
    });
}

// 選択されたVTuberを自動登録
async function autoRegisterSelected() {
    const selectedCheckboxes = document.querySelectorAll('.vtuber-item.new input[type="checkbox"]:checked');

    if (selectedCheckboxes.length === 0) {
        alert('登録するVTuberを選択してください');
        return;
    }

    if (!confirm(`${selectedCheckboxes.length}人のVTuberを一括登録しますか？`)) {
        return;
    }

    const registerBtn = document.getElementById('autoRegisterBtn');
    registerBtn.disabled = true;
    registerBtn.textContent = '登録中...';

    let successCount = 0;
    let errorCount = 0;

    for (const checkbox of selectedCheckboxes) {
        const channelId = checkbox.dataset.channelId;
        const vtuberItem = checkbox.closest('.vtuber-item');
        const twitterInput = vtuberItem.querySelector('.twitter-input');
        const officeSelect = vtuberItem.querySelector('.office-select');
        const twitterName = twitterInput ? twitterInput.value.trim() : '';
        const selectedOfficeValue = officeSelect ? officeSelect.value : '';

        try {
            // チャンネル詳細情報を取得
            const response = await fetch(`${currentApiBase}/getChannelDetails`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ channelId })
            });

            const channelData = await response.json();
            const debutInput = entry.querySelector('[data-field="debut"]');
            const debutValue = debutInput ? debutInput.value.trim() : '';
            let channeID = channelInput.value.trim();
            if (channeID.startsWith('@')) {
                channeID = await convertHandleToChannelId(channeID);
            }
            // VTuberデータとして登録
            const vtuberData = {
                name: nameInput.value.trim(),
                channeID: channeID, // ← channeIDで送信
                twitterName: twitterInput.value.trim(),
                birthday: birthdayValue,
                office: selectedOffice,
                officeFlg: officeFlgRadio.value === 'true',
                debut: debutValue // 空でも必ず送信
            };

            await fetch(`${currentApiBase}/addVtuberData`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(vtuberData)
            });

            vtuberItem.classList.add('registered');
            successCount++;

        } catch (error) {
            console.error(`${channelId}の登録エラー:`, error);
            vtuberItem.classList.add('error');
            errorCount++;
        }
    }

    registerBtn.disabled = false;
    registerBtn.textContent = '選択したVTuberを自動登録';

    alert(`登録完了: ${successCount}件成功, ${errorCount}件エラー`);

    // 既存データキャッシュを更新
    await loadExistingVtuberData();
}

// アプリ初期化時に呼び出す（既存のinitializeApp関数に追加）
const originalInitializeApp = window.initializeApp;
window.initializeApp = function () {
    if (originalInitializeApp) {
        originalInitializeApp();
    }

    // 既存データキャッシュを読み込み
    loadExistingVtuberData();
};

// 初期化（認証後に実行される）
// DOMContentLoadedは認証チェック後に処理されるため、ここでは不要

// ===============================
// VTuber管理機能
// ===============================

let allRegisteredVtubers = [];
let filteredVtubers = [];
let selectedVtuberKeys = new Set();
let searchTimeout = null; // 検索のデバウンス用

// VTuber一覧を再取得して表示する関数（switchTab等から呼び出し用）
async function loadRegisteredVtubers() {
    // データ取得
    let vtuberData = await fetchAllVtuberData();
    if (!vtuberData) {
        allRegisteredVtubers = [];
        filteredVtubers = [];
        displayVtuberList();
        updateVtuberStats();
        return;
    }
    // 正規化
    let vtuberList = [];
    // どんなデータ形式でもObject.entriesでkeyを取得しdbKeyとして保存
    if (Array.isArray(vtuberData)) {
        allRegisteredVtubers = vtuberData.map((vtuber, index) => ({
            ...vtuber,
            key: vtuber.key || index,
            dbKey: vtuber.key || index
        }));
    } else if (vtuberData.vtuberDataList && typeof vtuberData.vtuberDataList === 'object') {
        allRegisteredVtubers = Object.entries(vtuberData.vtuberDataList).map(([key, vtuber]) => ({
            ...vtuber,
            key: vtuber.key || key,
            dbKey: key
        }));
    } else if (typeof vtuberData === 'object') {
        allRegisteredVtubers = Object.entries(vtuberData).map(([key, vtuber]) => ({
            ...vtuber,
            key: vtuber.key || key,
            dbKey: key
        }));
    } else {
        allRegisteredVtubers = [];
    }
    filteredVtubers = [...allRegisteredVtubers];
    displayVtuberList();
    updateVtuberStats();
}
// Office選択肢を更新
async function updateOfficeFilterOptions() {
    const officeSelect = document.getElementById('officeFilterSelect');
    const currentValue = officeSelect.value;

    // 既存の選択肢をクリア（最初の2つは残す）
    while (officeSelect.children.length > 2) {
        officeSelect.removeChild(officeSelect.lastChild);
    }

    // 利用可能なOffice一覧を取得
    await loadAvailableOffices();

    // Office選択肢を追加
    for (const [key, displayName] of Object.entries(availableOffices)) {
        if (key !== 'personal') {
            const option = document.createElement('option');
            option.value = key;
            option.textContent = displayName;
            officeSelect.appendChild(option);
        }
    }

    // 前の選択値を復元
    officeSelect.value = currentValue;
}

// VTuber一覧を表示
function displayVtuberList() {
    const container = document.getElementById('vtuberListContainer');

    console.log('displayVtuberList called with filteredVtubers:', filteredVtubers.length, 'items');
    console.log('First 3 filtered vtubers:', filteredVtubers.slice(0, 3));

    if (filteredVtubers.length === 0) {
        container.innerHTML = '<div style="padding: 40px; text-align: center; color: #666;">条件に一致するVTuberが見つかりませんでした</div>';
        // return; ←関数内であれば残す、グローバルなら削除
    }
    // シンプルなテーブル表示でデータを確認
    let html = '<table style="width:100%;border-collapse:collapse;">';
    html += '<thead><tr style="background:#f0f0f0;"><th style="padding:6px;border:1px solid #ccc;">No</th><th style="padding:6px;border:1px solid #ccc;">選択</th><th style="padding:6px;border:1px solid #ccc;">サムネイル</th><th style="padding:6px;border:1px solid #ccc;">名前</th><th style="padding:6px;border:1px solid #ccc;">チャンネルID</th><th style="padding:6px;border:1px solid #ccc;">事務所</th></tr></thead><tbody>';
    filteredVtubers.forEach(vtuber => {
        const channelId = vtuber.channelId && vtuber.channelId !== 'N/A' ? vtuber.channelId : (vtuber.channeID && vtuber.channeID !== 'N/A' ? vtuber.channeID : '');
        const name = vtuber.name && vtuber.name !== 'N/A' ? vtuber.name : (vtuber.twitterName && vtuber.twitterName !== 'N/A' ? vtuber.twitterName : '');
        let thumbnailUrl = '';
        if (vtuber.thumbnailUrl && vtuber.thumbnailUrl !== 'N/A') {
            thumbnailUrl = vtuber.thumbnailUrl;
        } else if (channelId && channelId.startsWith('UC')) {
            thumbnailUrl = `https://yt3.googleusercontent.com/ytc/${channelId}`;
        } else {
            thumbnailUrl = '/images/noImage200200.png';
        }
        // チェックボックスのchecked状態
        const checked = selectedVtuberKeys.has(vtuber.key) ? 'checked' : '';
        html += `<tr>
                <td style="padding:6px;border:1px solid #ccc;text-align:center;">${vtuber.dbKey}</td>
                <td style="padding:6px;border:1px solid #ccc;text-align:center;">
                    <input type="checkbox" data-key="${vtuber.key}" ${checked} onclick="toggleVtuberSelection('${vtuber.key}')">
                </td>
                <td style="padding:6px;border:1px solid #ccc;text-align:center;"><img src="${thumbnailUrl}" alt="thumb" style="width:48px;height:48px;border-radius:6px;background:#eee;"></td>
                <td style="padding:6px;border:1px solid #ccc;">${name}</td>
                <td style="padding:6px;border:1px solid #ccc;">${channelId}</td>
                <td style="padding:6px;border:1px solid #ccc;">${vtuber.office || ''}</td>
            </tr>`;
    });
    html += '</tbody></table>';
    // 削除ボタンを追加
    html += `<div style="margin:12px 0;text-align:right;"><button id="deleteSelectedBtn" onclick="deleteSelectedVtubers()" style="padding:8px 16px;background:#dc3545;color:#fff;border:none;border-radius:4px;cursor:pointer;">選択したVTuberを削除</button></div>`;
    container.innerHTML = html;
    updateSelectionStatus();
}

// VTuber選択状態をトグル
function toggleVtuberSelection(key) {
    if (selectedVtuberKeys.has(key)) {
        selectedVtuberKeys.delete(key);
    } else {
        selectedVtuberKeys.add(key);
    }

    // 表示を更新
    const item = document.querySelector(`[data-key="${key}"]`);
    if (item) {
        if (selectedVtuberKeys.has(key)) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    }

    updateSelectionStatus();
}

// 選択状態の表示を更新
function updateSelectionStatus() {
    document.getElementById('selectedVtuberCount').textContent = selectedVtuberKeys.size;
}

// VTuber統計を更新
function updateVtuberStats() {
    document.getElementById('totalVtuberCount').textContent = allRegisteredVtubers.length;
    document.getElementById('displayedVtuberCount').textContent = filteredVtubers.length;
}

// VTuber検索（デバウンス付き）
function searchVtubers(immediate = false) {
    // デバウンス処理（即座に実行する場合はスキップ）
    if (!immediate) {
        if (searchTimeout) {
            clearTimeout(searchTimeout);
        }
        searchTimeout = setTimeout(() => searchVtubers(true), 300);
        return;
    }

    const searchTerm = document.getElementById('vtuberSearchInput').value.toLowerCase().trim();
    const officeFilter = document.getElementById('office-filter-select').value;

    // 検索条件が何も指定されていない場合は全件表示
    if (!searchTerm && !officeFilter) {
        filteredVtubers = [...allRegisteredVtubers];
        displayVtuberList();
        updateVtuberStats();
        return;
    }

    filteredVtubers = allRegisteredVtubers.filter(vtuber => {
        // null/undefinedチェックを強化
        const name = vtuber.name || '';
        const channelId = vtuber.channelId || '';
        const twitterName = vtuber.twitterName || vtuber.twitter || '';
        const office = vtuber.office || 'personal';

        // 名前またはチャンネルIDで検索
        const matchesSearch = !searchTerm ||
            name.toLowerCase().includes(searchTerm) ||
            channelId.toLowerCase().includes(searchTerm) ||
            twitterName.toLowerCase().includes(searchTerm);

        // Office フィルタ
        const matchesOffice = !officeFilter || office === officeFilter;

        return matchesSearch && matchesOffice;
    });

    displayVtuberList();
    updateVtuberStats();
}

// 検索リセット
function resetVtuberSearch() {
    // タイムアウトをクリア
    if (searchTimeout) {
        clearTimeout(searchTimeout);
    }

    document.getElementById('vtuberSearchInput').value = '';
    document.getElementById('officeFilterSelect').value = '';

    // 全件表示
    filteredVtubers = [...allRegisteredVtubers];
    displayVtuberList();
    updateVtuberStats();
}

// 全選択
function selectAllVtubers() {
    filteredVtubers.forEach(vtuber => {
        selectedVtuberKeys.add(vtuber.key);
    });
    displayVtuberList();
}

// 全選択解除
function deselectAllVtubers() {
    selectedVtuberKeys.clear();
    displayVtuberList();
}

// 単一VTuber削除
async function deleteVtuber(key, name) {
    if (!confirm(`「${name}」を削除しますか？\n\n※この操作は取り消せません。`)) {
        return;
    }

    try {
        const response = await fetch(`${currentApiBase}/deleteVtuberData`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ key })
        });

        const result = await response.json();

        if (result.success) {
            alert(`「${name}」を削除しました。`);
            clearVtuberDataCache(); // キャッシュクリア
            if (selectedOffice) {
                await displayOfficeVtubers(selectedOffice); // 事務所ごとの一覧を再表示
            } else {
                await loadRegisteredVtubers(); // 全体一覧を再表示
            }
            selectedVtuberKeys.delete(key); // 選択状態をクリア
        } else {
            throw new Error(result.error || '削除に失敗しました');
        }
    } catch (error) {
        console.error('VTuber削除エラー:', error);
        alert(`削除エラー: ${error.message}`);
    }
}

// 選択したVTuberを削除
async function deleteSelectedVtubers() {
    if (selectedVtuberKeys.size === 0) {
        alert('削除するVTuberを選択してください。');
        return;
    }

    const selectedNames = Array.from(selectedVtuberKeys).map(key => {
        const vtuber = allRegisteredVtubers.find(v => v.key === key);
        return vtuber ? vtuber.name : key;
    });

    const confirmMessage = `以下の${selectedVtuberKeys.size}人のVTuberを削除しますか？\n\n${selectedNames.join('\n')}\n\n※この操作は取り消せません。`;

    if (!confirm(confirmMessage)) {
        return;
    }

    try {
        let successCount = 0;
        let errorCount = 0;
        for (const key of selectedVtuberKeys) {
            try {
                const vtuber = allRegisteredVtubers.find(v => v.key === key);
                let channelId = vtuber ? vtuber.channelId : undefined;
                if ((!channelId || channelId === 'N/A') && vtuber && vtuber.channeID) {
                    channelId = vtuber.channeID;
                }
                let bodyObj = { key };
                if (channelId && channelId !== 'N/A') {
                    bodyObj.channelId = channelId;
                }
                const response = await fetch(`${currentApiBase}/deleteVtuberData`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(bodyObj)
                });
                const result = await response.json();
                if (result.success) {
                    successCount++;
                } else {
                    errorCount++;
                    showStatus(`❌ 削除失敗: ${key} ${result.error || JSON.stringify(result) || 'VTuber削除中にエラーが発生しました'}`, 'error');
                }
            } catch (error) {
                errorCount++;
                showStatus(`❌ 削除エラー: ${key} ${error.message}`, 'error');
            }
        }

        alert(`削除完了: ${successCount}件成功, ${errorCount}件エラー`);

        selectedVtuberKeys.clear();

        // キャッシュクリア＋一覧再表示
        clearVtuberDataCache();
        if (selectedOffice) {
            await displayOfficeVtubers(selectedOffice);
        } else {
            await loadRegisteredVtubers();
        }

    } catch (error) {
        console.error('一括削除エラー:', error);
        alert(`一括削除エラー: ${error.message}`);
    }
}