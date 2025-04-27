import SwiftUI
import MessageUI

enum MailViewResult {
    case cancelled
    case saved
    case sent
    case failed
}

struct MailView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    var mailData: MailData

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(mailData.toRecipients)
        composer.setSubject(mailData.subject)
        composer.setMessageBody(mailData.messageBody, isHTML: false)
        
        // Add attachment if available
        if let data = mailData.attachment,
           let mimeType = mailData.attachmentMimeType,
           let filename = mailData.attachmentFilename {
            composer.addAttachmentData(data, mimeType: mimeType, fileName: filename)
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, 
                                   didFinishWith result: MFMailComposeResult, 
                                   error: Error?) {
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            parent.isPresented = false
        }
    }
}

// Add MailSheet extension for SwiftUI integration
extension View {
    func mailSheet(mailData: Binding<MailData?>, isShowing: Binding<Bool>, result: Binding<Result<MFMailComposeResult, Error>?>) -> some View {
        self.sheet(isPresented: isShowing) {
            if let mailData = mailData.wrappedValue {
                MailView(isPresented: isShowing, result: result, mailData: mailData)
                    .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
    
    func mailSheet(mailData: Binding<MailData?>, isShowing: Binding<Bool>, result: Binding<MailViewResult?>) -> some View {
        self.sheet(isPresented: isShowing) {
            if let mailData = mailData.wrappedValue {
                MailView(isPresented: isShowing, result: Binding<Result<MFMailComposeResult, Error>?>(
                    get: { nil },
                    set: { newValue in
                        if let newValue = newValue {
                            switch newValue {
                            case .success(let mailResult):
                                switch mailResult {
                                case .cancelled: result.wrappedValue = .cancelled
                                case .saved: result.wrappedValue = .saved
                                case .sent: result.wrappedValue = .sent
                                case .failed: result.wrappedValue = .failed
                                @unknown default: result.wrappedValue = .failed
                                }
                            case .failure:
                                result.wrappedValue = .failed
                            }
                        }
                    }
                ), mailData: mailData)
                .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
} 