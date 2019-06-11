//
//  ChatViewController.swift
//  ChatApp
//
//  Created by 西谷恭紀 on 2019/06/09.
//  Copyright © 2019 西谷恭紀. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Firebase

/*
 UIViewControllerを消してMessagesViewControllerを
入れることでMessageKitのUIを使えるようになる
 */
class ChatViewController: MessagesViewController {
    
    //外部のファイルから書き換えられないようにprivate
    private var ref: DatabaseReference! //RealtimeDatabaseの情報を参照
    private var user: User!             //ユーザ情報
    private var handle: DatabaseHandle! //オブザーバーの破棄を適切にする処理
    var messageList: [Message] = []     //Message型のオブジェクトの入る配列
    var sendData: [String: Any] = [:]   //Realtimeデータベースに書き込む内容を格納する辞書
    var readData: [[String: Any]] = []  //RealtimeDatabaseからの読み込み
    
    let dateFormatter:DateFormatter = DateFormatter() //日時のフォーマットを管理するもの
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //データベースを生成して参照情報をインスタンス化
        ref = Database.database().reference()   //リファレンス(参照)の初期化
        user = Auth.auth().currentUser          //ユーザー認証した現在のユーザーを格納
        
        //各種デリゲートをこのVCに設定(拡張機能)
        //messagesCollectionViewはチャット画面の中の各ユーザーメッセージのデータの塊
        //各機能が備わっているデリケードをChatViewControllerで使えるように定義している
        //先に書くとエラーがでるが､拡張機能の追加で消える
        //データの扱い
        messagesCollectionView.messagesDataSource = self as MessagesDataSource
        //レイアウト
        messagesCollectionView.messagesLayoutDelegate = self as MessagesLayoutDelegate
        //ディスプレイ
        messagesCollectionView.messagesDisplayDelegate = self as MessagesDisplayDelegate
        //Cellの扱い方
        messagesCollectionView.messageCellDelegate = self as MessageCellDelegate
        //文字入力の部分
        messageInputBar.delegate = self as InputBarAccessoryViewDelegate
        
        // メッセージ入力が始まった時に一番下までスクロールする
        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        // 表示している画面とキーボードの重複を防ぐ
        maintainPositionOnKeyboardFrameChanged = true // default false
        
        //DateFormatter()で日付と時刻と地域を指定(今回は日本時間を指定)
        dateFormatter.dateStyle = .medium //日付の表示スタイルを決定
        dateFormatter.timeStyle = .short  //時刻の表示スタイルを決定
        dateFormatter.locale = Locale(identifier: "ja_JP")//地域を決定
    }
    
    //RealtimeDatabaseに書き込みをする際の処理(JSONだと読みやすい)
    //Firebaseにチャット内容を保存するためのメソッド
    //Firebaseに送りたい情報は今回はテキスト
    func sendMessageToFirebase(text: String){
        if !sendData.isEmpty {sendData = [:] } //辞書の初期化(送信データの中身がからじゃなければ空にする)
        let sendRef = ref.child("chats").childByAutoId()//自動生成の文字列の階層までのDatabaseReferenceを格納
        let messageId = sendRef.key! //自動生成された文字列(AutoId)を格納
//        print("sendRefの中身\n\(sendRef)")
//        print("messageIdの中身\n\(messageId)")
        
        //これがJSON(書き方のルール的な)
        sendData = ["senderName": user?.displayName,//送信者の名前
                    "senderId": user?.uid,          //送信者のID
                    "content": text,                //送信内容（今回は文字のみ）
                    "createdAt": dateFormatter.string(from: Date()),//送信時刻
                    "messageId": messageId //送信メッセージのID
        ]
//        print(sendData)
        sendRef.setValue(sendData) //ここで実際にデータベースに書き込んでいます
    }
    
    
    
    
    /*
     ref - Databaseの情報を参照
     .child("chats") - "chats"という名前の階層の下
     .queryLimited(toLast: 25) - 最後から25件を取得
     .queryOrdered(byChild: "createdAt") - 下の階層にある"createdAt"を元に並び替え
     .observe(.value) - valueタイプでオブザーバーをセット
     */
    //メッセージが追加された際に読み込んで画面を更新するメソッド
    func updateViewWhenMessageAdded() {
        //古い順にとって降順にしている
        handle = ref.child("chats").queryLimited(toLast: 25).queryOrdered(byChild: "createdAt").observe(.value) { (snapshot: DataSnapshot) in
            DispatchQueue.main.async {//クロージャの中を同期処理
                self.snapshotToArray(snapshot: snapshot)//スナップショットを配列(readData)に入れる処理。下に定義
                self.displayMessage() //メッセージを画面に表示するための処理
//                print("readData: \(self.readData)")
            }
        }
    }
    
//    func deleteViewMessage() {
//        if editingStyle == .delete{
//            //indexPath.rowで認識された場所と同じ場所で削除の処理が実行する
//            resultArray.remove(at: indexPath.row)
//            //消去したことを保存
//            UserDefaults.standard.set(resultArray, forKey: "yamachan")
//            //tetableViewの更新
//            tableView.reloadData()
//    }
    
    //データベースから読み込んだデータを配列(readData)に格納するメソッド
    func snapshotToArray(snapshot: DataSnapshot){
        //中身を0
        if !readData.isEmpty {readData = [] }
        if snapshot.children.allObjects as? [DataSnapshot] != nil  {
            let snapChildren = snapshot.children.allObjects as? [DataSnapshot]
            for snapChild in snapChildren! {
                //要素を追加していく
                if let postDict = snapChild.value as? [String: Any] {
                    self.readData.append(postDict)
                }
            }
        }
    }
    
    //メッセージの画面表示に関するメソッド
    func displayMessage() {
        //メッセージリストを初期化
        if !messageList.isEmpty {messageList = []}
        
        for item in readData {
            print("item: \(item)\n")
            let message = Message(
                sender: Sender(id: item["senderId"] as! String,displayName: item["senderName"] as! String),
                messageId: item["messageId"] as! String,
                sentDate: self.dateFormatter.date(from: item["createdAt"] as! String)!,
                kind: MessageKind.text(item["content"] as! String)
            )
            messageList.append(message)
        }
        
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToBottom()
    }
    


    
    //viewが表示される直前に呼ばれるメソッド
    override func viewWillAppear(_ animated: Bool) {
        updateViewWhenMessageAdded() //画面が表示される直前に実行
    }
    
    //viewが表示されなくなる直前に呼び出されるメソッド
    override func viewWillDisappear(_ animated: Bool) {
        ref.child("chats").removeObserver(withHandle: handle)
    }
    
    
    
}

//ここから拡張機能↓
/*
 前のクラスと同じ名前を使うことができるが､メソッドを修正することができない為,
 新たなメソッドを作成する必要がある
 */


//MessageDataSourceの拡張

extension ChatViewController: MessagesDataSource {
    //自分の情報を設定
    //currentSender()(現在の画像の送信者)
    func currentSender() -> SenderType {
        //誰?(senderId: user.uid, displayName: user.displayName!)を参照して送信者を決定
        return Sender(senderId: user.uid, displayName: user.displayName!)
    }
    //表示するメッセージの数
    //セクションという1つのまとまりをTableのように扱っている
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }
    
//    private func performUpdatesForTypingIndicatorVisability(at section: Int) {
//        if isTypingIndicatorHidden {
//            messagesCollectionView.deleteSections([section - 1])
//        } else {
//            messagesCollectionView.insertSections([section])
//        }
//    }
    
    //メッセージの実態(中身)
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        //セクションの中身のメッセージをindexPathで呼び出している
        return messageList[indexPath.section] as MessageType
    }
    
    //セルの上の文字
    //これから表示する文字列の魅せ方(フォントどうするかとか)の設定
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            //属性付きの文字列を作る
            return NSAttributedString(
                //MessageKitの中のDate型を使っている
                string: MessageKitDateFormatter.shared.string(from: message.sentDate),
                //属性(見た目の処理)
                attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10),
                             NSAttributedString.Key.foregroundColor: UIColor.darkGray]
            )
        }
        return nil
    }
    
    // メッセージの上の文字(送信者の名前)
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        //送信者の名前を取得している
        let name = message.sender.displayName
        //送信者の名前を表示している
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
    
    // メッセージの下の文字(日付)
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        //日時を参照
        let formatter = DateFormatter()
        //日時の情報を全て取得している
        formatter.dateStyle = .full
        let dateString = formatter.string(from: message.sentDate)
        //日時の情報を全て表示している
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    
    
}

//MessageDisplayDelegateの拡張
// メッセージの見た目に関するdelegate
extension ChatViewController: MessagesDisplayDelegate {
    
    // メッセージの色を変更
    //三項演算子  条件式(True : False) if文を1行で書くパターンらしい
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        //現在ログインしている人からの情報であるのならばTrue(white)｡違ってたらFalse(darkText)｡
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    // メッセージの背景色を変更している
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        //現在ログインしている人からの情報であるのならばTrue｡違ってたらFalse｡
        return isFromCurrentSender(message: message) ?
            UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1) :
            UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    // メッセージの枠にしっぽ(吹き出しっぽくみせるやつ)を付ける
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        //現在ログインしている人からの情報であるのならば吹き出しっぽくみせるやつをTrue(右に出す)｡違ってたらFalse(左に出す)｡
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
    
    // アイコンをセット
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        // message.sender.displayNameとかで送信者の名前を取得できるので
        // そこからイニシャルを生成するとよい
        // 課題:特定のアイコンを設定する方法を考える
        let avatar = Avatar(initials: message.sender.displayName)
        avatarView.set(avatar: avatar)
    }
}

//MessageLayoutDelegateの拡張
// 各ラベルの高さを設定（デフォルト0なので必須）、メッセージの表示位置に関するデリゲート
extension ChatViewController: MessagesLayoutDelegate {
    
    //cellTopLabelAttributedTextを表示する高さ
    //Cellの上の方に表示する高さはどれくらいにするか
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        //現在位置からは10放している
        if indexPath.section % 3 == 0 { return 10 }
        return 0
    }
    
    //messageTopLabelAttributedTextを表示する高さ
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
    //messageBottomLabelAttributedTextを表示する高さ
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
}

//MessageCellDelegateの拡張
extension ChatViewController: MessageCellDelegate {
    
    // メッセージをタップした時の挙動
    func didTapMessage(in cell: MessageCollectionViewCell) {
        //alertの内容を定義
        let alert = UIAlertController(title: "削除", message: "このメッセージを削除しますか?", preferredStyle: UIAlertController.Style.alert)
        let cancelAction = UIAlertAction(title: "キャンセル", style: .default)
        let deleteAction = UIAlertAction(title: "削除する", style: .destructive) { (action: UIAlertAction) in
            
            //削除ボタンを押したら発動する処理
            self.ref.child("chats")removeValue()
            
        }
        //aleartを発報
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        present(alert, animated: true, completion: nil)
//        alert.addAction(UIAlertAction(title: "No", style: UIAlertAction.Style.cancel, handler: nil))
//        alert.addAction(UIAlertAction(title: "削除する", style: UIAlertAction.Style.destructive, handler: nil))
//        self.present(alert, animated: true, completion: nil)
        
//        swich alert.addAction() {
//        case
        
//        }
        messagesCollectionView.reloadData()
        print(alert.addAction)
        print("Message tapped")
    }
}

//InputAccessoryViewDelegateの拡張
extension ChatViewController: InputBarAccessoryViewDelegate {
    // メッセージ送信ボタンを押されたとき
    // inputBar(textField)についている送信ボタンを押したとき
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        //Firebaseに送信するメソッド
        sendMessageToFirebase(text: text)
        //inputBarの中のテキストを表示して
        inputBar.inputTextView.text = ""
        //一番下までスクロールしている
        messagesCollectionView.scrollToBottom()
//        print("messageList when sendButton pressed:\(messageList)")
    }
}
