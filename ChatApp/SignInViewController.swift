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
            
        GIDSignIn.sharedInstance()?.uiDelegate = self
        GIDSignIn.sharedInstance()?.delegate = self
        // Do any additional setup after loading the view.
    }
    //チャット画面への遷移メソッド

    func transitionToChatRoom() {
        //"toChatRoom"というIDで識別
        performSegue(withIdentifier: "toChatRoom", sender: self)//"toChatRoom"というIDで識別
    }
    
    //Googleサインインに関するデリゲートメソッド
    //signIn:didSignInForUser:withError: メソッドで、Google ID トークンと Google アクセス トークンを
    //GIDAuthentication オブジェクトから取得して、Firebase 認証情報と交換します。
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        guard let authentication = user.authentication else { return }
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        
        
        //最後に、認証情報を使用して Firebase での認証を行います
        Auth.auth().signInAndRetrieveData(with: credential) { (authDataResult, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            print("\nSignin succeeded\n")
            self.transitionToChatRoom()
        }
    }
    
    //SignOutボタンが押されたとき
    @IBAction func tappedSignOut(_ sender: UIButton) {
        //ログアウト機能の実装
        //認証情報
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            print("SignOut is succeeded")
            reloadInputViews()
        } catch let signOutError as NSError {
            //エラーでたら出す
            print("Error signing out: %@", signOutError)
        }
        
    }
    

}
