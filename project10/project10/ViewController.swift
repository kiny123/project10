//
//  ViewController.swift
//  project10
//
//  Created by nikita on 27.01.2023.
//

import LocalAuthentication
import UIKit

class ViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var people = [Person]()
    
    var hiddenPeople = [Person]()
    var unlockButton: UIBarButtonItem!
    var addPersonButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addPersonButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPerson))
        
        unlockButton = UIBarButtonItem(title: "Unlock", style: .plain, target: self, action: #selector(unlockTapped))
        navigationItem.rightBarButtonItem = unlockButton
        
        let defaults = UserDefaults.standard
        
        if let savedPeople = defaults.object(forKey: "people") as? Data {
            let jsonDecoder = JSONDecoder()
            
            do {
                hiddenPeople = try jsonDecoder.decode([Person].self, from: savedPeople)
            }
            catch {
                print("Failed to load people")
            }
        }
        
        let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(self, selector: #selector(lock), name: UIApplication.willResignActiveNotification, object: nil)
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return people.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Person", for: indexPath) as! PersonCell
        
        let person = people[indexPath.item]
        
        cell.name.text = person.name
        
        let path = getDocumentsDirectory().appendingPathComponent(person.image)
        cell.imageView.image = UIImage(contentsOfFile: path.path)
        
        cell.imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.cornerRadius = 3
        cell.layer.cornerRadius = 7
        
        return cell
        
    }
    
    func deletePersonTapped(at indexPath: IndexPath) {
        let ac = UIAlertController(title: "Confirmation", message: "Delete person \"\(people[indexPath.item].name)\"?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.deletePerson(at: indexPath)
        }))
        
        present(ac, animated: true)
    }
    
    func deletePerson(at indexPath: IndexPath) {
        DispatchQueue.global().async { [weak self] in
            guard let image = self?.people[indexPath.item].image else {
                self?.showDeleteError()
                return
            }
            
            guard let imagePath = self?.getDocumentsDirectory().appendingPathComponent(image) else {
                self?.showDeleteError()
                return
            }
            
            do {
                try FileManager.default.removeItem(at: imagePath)
            }
            catch {
                self?.showDeleteError()
                return
            }
            
            self?.people.remove(at: indexPath.item)
            
            DispatchQueue.main.async {
                self?.collectionView.deleteItems(at: [indexPath])
            }
        }
    }
    func showDeleteError() {
        DispatchQueue.main.async { [weak self] in
            let ac = UIAlertController(title: "Error", message: "Person could not be deleted", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            
            self?.present(ac, animated: true)
        }
    }
    
    @objc func addNewPerson() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let ac = UIAlertController(title: "Source", message: nil, preferredStyle: .actionSheet)
            ac.addAction(UIAlertAction(title: "Photos", style: .default, handler: { [weak self] _ in
                self?.showPicker(fromCamera: false)
            }))
            ac.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
                self?.showPicker(fromCamera: true)
            }))
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ac.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
            
            present(ac, animated: true)
        }
        else {
            showPicker(fromCamera: false)
        }
    }
    
    func showPicker(fromCamera: Bool) {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        if fromCamera {
            picker.sourceType = .camera
        }
        present(picker, animated: true)
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            let imageName = UUID().uuidString
            let imagePath = self?.getDocumentsDirectory().appendingPathComponent(imageName)
            
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                if let imagePath = imagePath {
                    try? jpegData.write(to: imagePath)
                }
            }
            
            let person = Person(name: "Unknown", image: imageName)
            self?.people.append(person)
            
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
                self?.dismiss(animated: true)
            }
        }
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let person = people[indexPath.item]
        
        let ac = UIAlertController(title: "Person", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Rename person", style: .default, handler: { [weak self] action in
            self?.renamePersonTapped(person)
        }))
        ac.addAction(UIAlertAction(title: "Delete person", style: .destructive, handler: { [weak self] action in
            self?.deletePersonTapped(at: indexPath)
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.collectionView?.reloadData()
        
        
        present(ac, animated: true)
    }
    func renamePersonTapped(_ person: Person) {
        let ac = UIAlertController(title: "Rename person", message: nil, preferredStyle: .alert)
        ac.addTextField()
        
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak ac] _ in
            guard let newName = ac?.textFields?[0].text else {
                return
            }
            person.name = newName
            self?.collectionView.reloadData()
        })
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    @objc func unlockTapped() {
           let context = LAContext()
           var error: NSError?

           guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
               showAlert(title: "Unavailable", message: "Biometrics authentication is not available")
               return
           }

           var reason = ""
           switch context.biometryType {
           case .none:
               showAlert(title: "Unavailable", message: "Biometrics authentication is not available")
               return
           case .faceID:
               reason = "Use Face ID to access your pictures"
           case .touchID:
               reason = "Use Touch ID to access your pictures"
           @unknown default:
               reason = "Use biometrics to access your pictures"
           }

           context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
               DispatchQueue.main.async {
                   guard success else {
                       self?.showAlert(title: "Failed", message: "Biometrics authentication failed")
                       return
                   }

                   self?.unlock()
               }
           }
       }
    
    func unlock() {
            navigationItem.leftBarButtonItem = addPersonButton
            navigationItem.rightBarButtonItem = nil
        people = hiddenPeople
        collectionView.reloadData()
        }

        @objc func lock() {
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = unlockButton
            people = [Person]()
            collectionView.reloadData()
        }
    
    func showAlert(title: String, message: String) {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    
    func save() {
            let jsonEncoder = JSONEncoder()

            if let savedData = try? jsonEncoder.encode(people) {
                let defaults = UserDefaults.standard
                defaults.set(savedData, forKey: "people")
            }
            else {
                print("Failed to save people")
            }
        }
    
    
}

extension ViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return  CGSize(width: 140, height: 180)
    }
}
