# 包 B（iCloud 傳輸與接頭）審查（2026-11-24，只讀不改，沒有 git 寫入；先讀程式，最後才看回報-JB）

## 結論
- **編不過：沒找到確定的。** 疑慮一筆（E1，補一行 import 就沒事）。隔離與 Sendable 逐檔對過：Swift 5 模式下沒有會擋編譯的。
- **必修 5 筆**（R1–R5），都是「會丟資料或寫錯」的路，各改幾行到十幾行。其中 R1、R2 動到帳本，要在出貨前定。
- **值得改 9 筆**（S1–S9），小事在後面。
- check_swift 0、check_refs 沒定義 0（我重跑過）。雲端沒跑，44 則測試是用讀的推，除了 S9 兩則都推得過。
- 已查、**沒事**的在最後一節，不用再查。

## 必修

### R1 用雜湊比 Apple 帳號，靠的是「封存的位元組每次都一樣」，Apple 沒這樣保證
- `ICloudDrive.swift:141-148`（fingerprint）、`:151-154`（check）、`CloudLink+Transfer.swift:192`。
- 情境：`NSKeyedArchiver` 的輸出含類別名與內部欄位，iOS 更新換了 token 的內部寫法，同一個帳號就算出不同的雜湊。後果兩個：①跳「換了 Apple 帳號」，按「先不要」就不同步，按「放進去」多一整個資料夾；②`eraseCloud` 拿舊雜湊去比，丟 otherAccount，**使用者永遠刪不掉 iCloud 那份**，只會一直看到「沒刪成，再試一次」。
- Apple 的說法：token 是不透明物件，可以拷貝、編碼、用 `isEqual:` 比；舊的 iCloud Design Guide 範例存的是封存後的 Data，不是雜湊。
- 怎麼改：帳本 `identity` 存封存 Data 的 base64，不存雜湊。協定改成 `func identity(like known: String?) async throws -> String?`：known 解得開、而且 `token.isEqual(解開的)` 就回 known 原字串，否則回新封存的 base64。這樣 CloudLink 那邊照舊比字串。`check(_:)` 也走同一支。解開用 `NSKeyedUnarchiver(forReadingFrom:)`，`requiresSecureCoding = false`，`decodeObject(forKey: NSKeyedArchiveRootObjectKey)`。解不開當成不同。fake 的 `identity(like:)` 不看參數就好。帳本在自己沙盒、不進備份，存原 token 不會比存雜湊多洩漏什麼。
- 確定程度：違反 Apple 的用法＝高；真機會不會真的變＝查不到證據（有人做過同題，結論也是「沒量過」）。改起來便宜、出貨後改會讓所有人被誤問一次，所以列必修。

### R2 帳本存失敗會把舊的好帳本刪掉；讀失敗也當成沒有：換帳號那道問就不見了
- `CloudLedger.swift:56-69`：`write(to:options:.atomic)` 失敗（磁碟滿）也走 catch 的 `remove()`，舊帳本原本好好的，被刪了。`:38-44`：`try? Data(contentsOf:)` 讀不到（還沒解鎖過、檔案系統一時錯誤）等於沒有帳本。
- 情境：磁碟滿時傳一次 → 帳本沒了。這段時間使用者換了 Apple ID，下次打開：沒帳本＝第一次，`book.identity` 是 nil，`list` 不問，**整份直接合進、傳進另一個 Apple ID**。沒換帳號的也會多一個編號、多一整份。
- 怎麼改：
  1. `save`：寫失敗只回 false，不刪；只有「寫成了但不進備份的記號標不上」才刪。更好的是寫暫存檔 → 標記 → `replaceItemAt`（記號會跟著暫存檔），就沒有「剛寫完還沒標就被殺」的空窗。
  2. `load` 分三種：沒有檔（fileExists 是 false）＝nil；讀不到＝丟錯，這輪不同步；讀到但解不開、編號不對、別支手機寫的＝nil。
  3. 加測試：先存好一本、把資料夾設唯讀再存，舊的還讀得到。
- 確定程度：程式路徑＝高；發生機率低，後果不可逆。

### R3 本機變空的時候會蓋掉自己在 iCloud 的那份，而且自己那份從來不讀回來
- `CloudLink+Transfer.swift:15`、`:42`（只讀別台）、`:105-113`（照本機整份寫）、`CloudLedger`（帳本跟狀態檔是兩個檔，會一個在一個不在）。
- 情境：只有一支手機。狀態檔變成 0 byte（斷電），`StateFile.load` 對空字串回空白狀態、`unreadable` 是 false。帳本還在、`seen` 是 true。打開同步：自己的資料夾跳過不讀，拉完 ready。使用者收一顆 → 這個月的檔被「只有這一顆」的版本蓋掉；`tags.json` 也換成預設標籤。以前的月份檔還在但這個編號永遠不會讀它。**iCloud 明明有完整一份，反而是這裡把它蓋掉。**
- 怎麼改：`pull` 開頭，本機 `days` 一筆紀錄都沒有、而 `book.sent` 有任何月份檔 → 不用這本帳：換新編號（沿用舊帳本的 `identity` 與 `seen`，換帳號照問）。舊資料夾就變成「別台」，自動合回來。`wipe` 本來就忘帳本，不受影響。
- 加測試：傳過 r1 的手機，host 換成 `Store.blank()` 重開，wakeUp 後 r1 要回來，舊月份檔原封不動。
- 確定程度：程式路徑＝高；發生機率低。

### R4 動手前比帳號比太早：在等 iCloud 讓路時換了帳號，會寫進或刪掉別人的
- `ICloudDrive.swift:51`、`:72`、`:94`：比完帳號才去 `coordinate`，中間最多可以等 10 秒；更實際的是這段剛好被系統暫停，使用者去設定換 Apple ID 再回來，執行緒醒來直接做完。iOS 上容器路徑不分帳號，所以真的會寫到、**刪到**新帳號的 `Records/`。
- 怎麼改：讀、寫、刪都在 accessor 裡第一行再比一次：`result = Result { try ICloudDrive.check(identity); try data.write(…) }`。外面那次可以留（早點失敗）。`createDirectory`（:74）也搬進 accessor。刪的 identity 是 nil 時照舊不比。
- 確定程度：程式路徑＝高；機率很低，但刪除不可逆，三行就好。

### R5 一台選了「也刪掉」，另一台會自己寫回去，不會停下來問
- `CloudLink+Transfer.swift:199`（整個清單空了才問）、`:108`（檔不見就補寫）、`ICloudDrive.swift:74`（資料夾不在就自己建）。
- 情境 A（很普通）：B 手機沒網路時收了一顆，`2026-11.json` 已改、還沒傳。A 手機關同步選「也刪掉」。B 連上網：iCloud 對「一邊刪一邊改」留改過的那份 → B 的清單剩自己的 `2026-11.json`，不是空的 → 不問，接著把 tags 與所有月份補寫回去（含 A 的番茄）。
- 情境 B：B 正在 `push` 的迴圈裡，清單是刪之前列的；刪除同步下來後，下一個 `write` 又把 `Records/` 建回來。
- 怎麼改：`list` 加一條：帳本 `sent` 裡的檔，這台的 `tags.json` 不在清單、或有兩個以上不在 → `ask(.emptied)`；只少一個月份檔照規格補寫。`sent` 是空的不看。這條拉、傳都會走到。`write` 在 `sent` 非空時資料夾不在就丟錯不建（第一次才建），可以擋掉情境 B 大部分。
- 加測試：兩台都傳過，刪掉 `Records/` 再把 B 的月份檔放回去，B wakeUp 要 `question == .emptied` 且沒有新寫的檔。現有「檔不見了就補寫」那則照樣過（少的是一個月份檔）。
- 確定程度：程式的判斷＝高；情境 A 的「留改過的」是 iCloud 一般行為，沒有真機驗過＝中。

## 值得改

### S1 清單收齊是空的，不等於雲端是空的
- `CloudCatalog.swift:83-88`、`CloudLink+Transfer.swift:197-201`。
- 情境：`DidFinishGathering` 只代表這支手機知道的列完了。同帳號登出再登入、iCloud 雲碟關掉再開、剛更新完系統，伺服器的清單還沒下來就會收齊 0 筆，磁碟也是空的；`seen` 是 true → 誤問「iCloud 裡的番茄不見了」。按「放進去」不會丟資料，但多一個編號、一份完整拷貝、一份自動備份（`BackupFiles` 的自動備份不會自己清）。
- 怎麼改：空的時候先不問，記下第一次看到空的時刻，隔 `cloudNoticeSeconds` 以上（建議新數字 10 秒）再列一次還是空的才問；期間不准傳。順便在要問之前再拿一次 identity，不同就改問 `.account`：現在清單列到一半換帳號會問錯成 `.emptied`，按了就寫進新帳號。
- 確定程度：高（誤問的路徑）；發生頻率要真機。

### S2 「放進去」沒有綁當時問的是哪個帳號
- `CloudLink+Switch.swift:57-62`。情境：問的是 B，框還開著，使用者切去設定又換成 C，回來按「放進去」→ 帳本 identity 是 nil，直接合進 C。換回原本的 A 再按也會多一份。
- 怎麼改：`ask` 記下當時的 identity；`adopt` 後第一次 `account` 拿到的不同就再問，跟原帳本相同就收掉問題、不換編號。確定程度：高；機率很低。

### S3 「清除所有資料＋也刪掉」做到一半被殺或失敗，就再也沒有入口刪
- `CloudLink+Switch.swift:28-35`：先忘帳本、再開 Task 刪；`eraseTarget` 只在記憶體。app 被殺、逾時、剛好登出 → 下次打開 `hasCopy` 是 false、沒有那句話，雲端那份還在。安全標準 P5 要求真的清乾淨。JB 自己有記。
- 怎麼改：要刪之前把目標寫進 UserDefaults（`cloudErasePending`：identity，空字串代表不比），刪成才清掉；`start` 時有值就設 `problem = .eraseFailed`、`hasCopy` 算 true。`eraseCloud` 也走這裡（在關掉到刪完之間被殺同一個洞）。不要自動重刪，讓使用者按。
- 包 E 留意：那句話在「owned 才列」的列底下，退款的人看不到也刪不了；有 pending 或 `hasCopy` 時建議照樣列出刪除那一句。確定程度：高。

### S4 這支手機上還沒有 `Records/` 時，刪雲端回「刪成了」
- `ICloudDrive.swift:97`。情境：剛登入回來、容器內容還沒下來，資料夾不在本機 → 直接 return，畫面說刪好了、帳本也忘了，之後別台的檔陸續下來，什麼都沒刪。
- 怎麼改：`erase` 先 `try await catalog.listed()`（有時限）；本機沒有資料夾而清單有東西 → 丟 `notReady`。刪完再看 `fileExists` 還在就丟錯。確定程度：程式高、發生中低。

### S5 兩支手機同編號時沒有任何偵測；衝突版本沒人讀
- `CloudLedger.swift:46-49`（任一邊 phone 是 nil 就認）、`CloudLink+Transfer.swift:107-113`。
- 情境：擋在 vendor 識別碼那一道失手（寫帳本那刻拿到 nil，帳本就永遠「誰都認」），兩支手機互蓋同一個路徑、也永遠不讀對方的；iCloud 變成 `NSFileVersion` 未解決衝突，輸的那份看不到。準則 5-20 第 2 條「上傳前先讀雲端那份比指紋」這裡沒做。
- 怎麼改：①`isMine`：帳本 phone 是 nil 而現在拿得到，就補寫；拿不到就這輪不同步（回到前景再試）。②寫自己的檔之前，`sent` 有記、檔在、下載好了就先讀來比 SHA，跟 `sent` 不同＝別人寫過 → 換新編號（沿用 identity、seen）再寫。這條也會抓到「寫完還沒記帳就被殺」，多一份無害；想避免就改成「跟 sent 不同、也跟要寫的不同」才算。
- 確定程度：程式高；發生很低。

### S6 拉失敗之後，同一份清單不會再觸發
- `CloudLink.swift:209-213`：先記 `lastNoticed` 再去拉；那趟逾時或讀不到（3 分鐘內不重讀），清單沒再變就要等回到前景。
- 怎麼改：`pull` 沒走到 `ready = true` 或有檔進 `resting` 時把 `lastNoticed` 清成 nil，並在 resting 到期時補一次 `pullSoon`。只清 lastNoticed 也可以。確定程度：高；影響是晚拿到，不丟。

### S7 停掉之後查詢可能又自己開起來
- `CloudCatalog.swift:21-22`、`ICloudDrive.swift:30-32`：`files()` 的 Task 還沒排到 `listed()`，這時 `turnOff` 已經 `stop()` 過，`listed()` 才跑，又 `start()` 一個沒人聽的查詢，關掉同步後還在跑（耗電、觀察者留著）。
- 怎麼改：`watch` 設 `isWatched = true`、`unwatch` 設 false；`listed()` 一開始 `guard isWatched else { throw CloudError.stopped }`。確定程度：高（時序窗很小）。

### S8 字
- `WordsCloud.swift:30`、`:32`「現在只存在這支手機」：同步過的人不準，iCloud 那份還在。改「新的番茄先存在這支手機。」
- `:33`「iCloud 那份沒刪成，點這裡再試一次。」：換了 Apple 帳號時怎麼點都不會成。另給一句：「iCloud 那份在別的 Apple 帳號，登入原本的才刪得掉。」`erase` 的 catch 分得出 `.otherAccount`，加一個 `CloudProblem.eraseOther`。
- `:22` 補一句手機裡的不會刪：「其他手機放進去的也會一起刪，手機裡的番茄不會動。」（清除所有資料那邊不能用後半句，要分兩個字串。）
- AI 味：沒有。確定程度：高。

### S9 兩則 CloudLine 測試看機器快慢，會偶爾紅
- `CloudFilesTests.swift:129-143`：0.05 秒內佇列（`.utility`）沒輪到，號碼牌就作廢，「寫檔」永遠不會出現，斷言紅。CI 機器忙的時候 50 毫秒不夠。`:108-127`：`stuck` 100 毫秒內沒排進佇列，「逾時的」會先做，跑到 XCTFail；反過來整體慢 300 毫秒也會。
- 怎麼改：用 `DispatchSemaphore`：卡住的那件進場時先記「開始了」、再等號誌；測試 `until` 看到「開始了」才送第二件，斷言逾時之後才放號誌。第一則的時限放寬到 0.3。確定程度：高（會不會真的紅看機器）。

## 編譯疑慮與小事（建議）
- **E1** `CloudLink+Transfer.swift:1`：用了 `CloudLink.log.error("\(…, privacy: .public)")` 卻沒 `import os`。Swift 5 模式靠同 target 其他檔的 import 多半會過；開了 MemberImportVisibility 就是「not available due to missing import of defining module 'os'」。repo 裡別的 Logger 檔都有 import。補 `import os`。確定程度：低到中，但一行。
- `CloudLink.swift:220` `guard let self, !(onlyIfUnready && ready)`：`&&` 右邊是 autoclosure、又在同一個 guard 裡用隱含 self。應該會過；不想賭就拆成兩個 guard。確定程度：低。
- `ICloudDrive.swift:161` `status == nil` 當成在，跟 :156 的註解相反。屬性讀得到但沒值＝不歸 iCloud 管的檔，讀它無害；改註解就好。0 byte、沒下載的檔會被 JSON 那關擋掉，不會當成「空的」合進來。
- `TimeLimit.swift:26-29`（包 C）：先回來的時候計時的 Task 沒取消，拉 100 個檔就有 100 個睡 10 秒的 Task。記下來 cancel。
- `CloudLink+Transfer.swift:54-65`：讀到一半換帳號的 `otherAccount` 當一般錯誤吞掉，靠接著的 `requestPush` 才問。結果是對的；直接往外丟、馬上 `ask(.account)` 比較乾淨。
- `CloudLedger`：`seen`、`sent` 的預設值對合成的 `init(from:)` 沒用，缺一個鍵整本當沒有。之後加欄位一律用 Optional。
- 換機還原：UserDefaults `cloudSync` 會跟著還原，帳本不會 → 新手機不問就合進它登入的 iCloud。照規格「備份再合」沒錯；轉給別人用的手機會把資料放進那個人的 iCloud。要不要在「開著但沒帳本」時問一句，給多米定。
- 測試缺口：`.account`／`.gathered` 通知、退款發生在傳一半、`wipe(erasing: true)` 失敗、`enteredBackground` 之後背景時間有還、`CloudTicket.cancel`（NSFileCoordinator 對本機檔可測：拿一個協調器卡住寫、第二個 run 逾時，檔不能被寫）、刪到一半重開。`ICloudDrive.check` 的比對邏輯抽成吃 `NSData` 的純函式就能測。
- `FakeHost.taken` 沒人用。`CloudLine` 開 `.utility`，進背景那幾秒搶不到時間時可考慮 `.userInitiated`。

## 查過、沒事
- **第一次拉完前就傳**：`ready` 只在拉完設；`stop` 清掉；`hasNews`、`push` 都看。清單列不出來不會設。
- **關掉後又寫回（這支）**：generation 在每個 await 後對號；只有已經進到 `write` 的那一個會寫完，`erase` 先等 worker，又排在同一條序列佇列後面。`forgetLedger` 之後不會被舊的 worker 寫回帳本。
- **逾時的殘留**：沒輪到的作廢、等協調器的 `cancel()`（任何執行緒可叫）、已經在寫的一定排在後來的刪除前面。`ReplyOnce` 不會回兩次。
- **拉的期間本機變**：`host.cloudState == base` 才換上，比較與換上之間沒有 await。
- **NSMetadataQuery**：scope `NSMetadataQueryUbiquitousDataScope`、predicate、主執行緒開關、`disableUpdates`／`enableUpdates` 成對、通知 `.main`＋`assumeIsolated`（跟 PoseWatch 同一種寫法）、停掉後的舊通知用 round 擋：都對。
- **兩台同時建 `Records/` 會不會變 `Records 2`**：TN2336 寫明改名只發生在 `Documents` 裡的檔案，外面的自動挑一份、輸的留成版本（不清會一直佔空間，所以 S5 值得做）。資料夾同名它沒特別寫，真機順手看一眼。「一邊刪一邊改」它也沒寫，R5 情境 A 要兩支手機驗。
- **BackgroundGrace**：到期與做完都走 `end`，只還一次；`erase` 的 throw 走 catch 後一定 `end`。
- **沒下載好的檔**：看狀態、請系統下載、跳過；`.icloud` 佔位檔名被 `locate` 擋掉、真名由查詢補。
- **路徑、大小、log**：CWE-22、I3、S8 都守住。
- **測試**：`busiest` 那幾則有設 pause，不是永遠過；等待最長 5 秒，平常 0.3 秒。
