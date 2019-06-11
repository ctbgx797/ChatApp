//
//  SignInViewController.swift
//  
//
//  Created by 西谷恭紀 on 2019/06/09.
//

import UIKit
import Firebase
import GoogleSignIn

class SignInViewController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate {
  
        override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
        GIDSignInDelegateのDelegateとGIDSignInUIDelegateのUIに
        直接どんな処理をするのかを書き加えるために
        self(SignInViewController)と書いている
        */
        GIDSignIn.sharedInstance()?.uiDelegate = self
        GIDSignIn.sharedInstance()?.delegate = self
        // Do any additional setup after loading the view.
    }
    
    //チャット画面への遷移メソッド
    func transitionToChatRoom() {
        //"toChatRoom"というIDで識別
        //formSegue(画面遷移) 矢印の向きに(どこ?="toChatRoom")
        performSegue(withIdentifier: "toChatRoom", sender: self)
    }
    
    //サインインの実装
    //Googleサインインに関するデリゲートメソッド
    //signIn:didSignInForUser:withError: メソッドで、Google ID トークンと Google アクセス トークンを
    //GIDAuthentication オブジェクトから取得して、Firebase 認証情報と交換します。
    
    //GoogleSignInに関する必要なメソッド
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        //エラーがあればデバッグエリアにメッセージを出力してリターンする
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        //user.authentication(認証するユーザー)がいなければreturnする
        guard let authentication = user.authentication else { return }
        //トークン(データの最小位単位)
        //認証するユーザーがいればaccessTokenとidTokenという認証情報をcredentialに格納する
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        
        
        //最後に、認証情報を格納したcredentialを使用して Firebase での認証を行います
        Auth.auth().signInAndRetrieveData(with: credential) { (authDataResult, error) in
            //エラーがあればデバッグエリアにメッセージを出力してリターンする
            if let error = error {
                print(error.localizedDescription)
                return
            //成功すればtransitionToChatRoomメソッドが発動して画面遷移を行う
            }
            //認証が成功すればデバッグエリアにメッセージを出力
            print("\nSignin succeeded\n")
            self.transitionToChatRoom()
        }
    }
    
    
    //サインアウト機能の実装
    //SignOutボタンが押されたとき
    @IBAction func tappedSignOut(_ sender: UIButton) {
        //認証情報をインスタンス化している
        let firebaseAuth = Auth.auth()
        do {
            //認証情報からサインアウトの処理を実施
            try firebaseAuth.signOut()
            //認証情報が正常にサインアウトできたら"SignOut is succeeded"をデバッグエリアへ出す
            print("SignOut is succeeded")
            //リロードしてあげる
            reloadInputViews()
        //もし認証情報がサインアウトエラーを出したら
        } catch let signOutError as NSError {
            //デバッグエリアにエラーを出す
            print("Error signing out: %@", signOutError)
        }
        
    }
    

}
