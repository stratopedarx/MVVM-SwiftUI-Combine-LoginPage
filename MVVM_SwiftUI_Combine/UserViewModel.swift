//
//  UserViewModel.swift
//  MVVM_SwiftUI_Combine
//
//  Created by Sergey Lobanov on 20.11.2021.
//

import Combine
import Foundation
import Navajo_Swift

/**
 Во-первых. определим ViewModel, у которой будет пара свойств для ввода данных пользователем  (имя пользователя username и пароль password), и на данный момент одно выходное (output) свойство isValid для представления результатов некоторой бизнес-логики проверки введенных пользователем username и password, которую мы собираемся внедрить в ближайшее время
 */
class UserViewModel: ObservableObject {
    // input
    @Published var username = ""
    @Published var password = ""
    @Published var passwordAgain = ""
    
    // output
    @Published var isValid = false
    @Published var usernameMessage = ""  // предупреждающие сообщения
    @Published var passwordMessage = ""  // предупреждающие сообщения
    
    
    private var cancellableSet: Set<AnyCancellable> = []
    
    // начнем с реализации конвейера для проверки паролей, введенных пользователем
    private var isPasswordEmptyPublisher: AnyPublisher<Bool, Never> {
        // (1)
        /**
         Проверить, является ли пароль password пустым, довольно просто, и вы можете заметить, что этот метод очень похож на нашу предыдущую проверку имени пользователя username.
         Но на этот раз вместо непосредственного присвоения результата преобразования выходному свойству isValid, мы возвращаем AnyPublisher<Bool, Never>.
         Мы поступаем так, потому что это промежуточное значение и позже мы будем объединять несколько наших пользовательских издателей Publishers  в многоступенчатую цепочку,
         прежде чем подпишемся на конечный результат (правильный или нет).
         */
        $password
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { password in
                return password == ""
            }
            .eraseToAnyPublisher()
            /**
             В случае, если вам интересно, почему мы должны вызывать eraseToAnyPublisher () в конце каждой цепочки, поясняю: это выполняет стирание некоторого ТИПА, оно гарантирует, что мы не получим некоторые сумасшедшие вложенные ТИПЫ возврата и сможем их встроить в любую цепочку.
             */
    }

    /**
     Чтобы проверить, содержат ли два отдельных свойства одинаковые строки String, мы используем оператор CombineLatest.
     Помните, что свойства, привязанные к соответствующим SecureField, запускаются каждый раз, когда пользователь вводит символ,
     и мы хотим сравнивать последние значения для каждого из этих полей. Оператор CombineLatest позволяет нам это делать.
     */
    private var arePasswordsEqualPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($password, $passwordAgain)
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .map { password, passwordAgain in
                return password == passwordAgain
            }
            .eraseToAnyPublisher()
    }
    
    
    /**
     Для расчета надежности пароля мы используем фреймворк Navajo Swift и преобразуем результирующее перечисление enum
     в Bool с помощью цепочки в другом издателе isPasswordStrongEnoughPublisher. В этом коде мы впервые подписываемся (subscribe) на один из наших собственных издателей passwordStrengthPublisher, и это очень наглядно показывает, как мы можем комбинировать
     множество издателей (наших собственных и встроенных в Combine) для получения требуемого выхода (output).
     
     В случае, если вам интересно, почему мы должны вызывать eraseToAnyPublisher () в конце каждой цепочки, поясняю:
     это выполняет стирание некоторого ТИПА, оно гарантирует, что мы не получим некоторые сумасшедшие вложенные ТИПЫ возврата и сможем их встроить в любую цепочку.
     */
    private var passwordStrengthPublisher: AnyPublisher<PasswordStrength, Never> {
        $password
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { input in
                return Navajo.strength(ofPassword: input)  // (2)
            }
            .eraseToAnyPublisher()
    }

    private var isPasswordStrongEnoughPublisher: AnyPublisher<Bool, Never> {
        passwordStrengthPublisher
            .map { strength in
                switch strength {
                case .reasonable, .strong, .veryStrong:
                    return true
                default:
                    return false
                }
            }
            .eraseToAnyPublisher()
    }
    
    
    /**
     Отлично — теперь мы много знаем о паролях, введенных пользователем, давайте сведем это к одной вещи, которую мы действительно хотим знать: этот  пароль password — правильный?
     Как вы уже догадались, нам нужно будет использовать оператор CombineLatest, но поскольку на этот раз у нас есть три параметра, мы будем использовать CombineLatest3, который принимает три входных параметра
     
     Основная причина, по которой мы преобразуем три логических значения в единственное перечисление, заключается в том, что мы хотим иметь возможность выдавать подходящее предупреждающее сообщение в зависимости от результата проверки.
     Сказать пользователю, что его пароль password не годится, не очень информативно, не так ли? Намного лучше, если мы скажем ему, почему этот пароль password не подходит.
     */
    enum PasswordCheck {
        case valid
        case empty
        case noMatch
        case notStrongEnough
    }
    
    private var isPasswordValidPublisher: AnyPublisher<PasswordCheck, Never> {
        Publishers.CombineLatest3(isPasswordEmptyPublisher, arePasswordsEqualPublisher, isPasswordStrongEnoughPublisher)
            .map { passwordIsEmpty, passwordsAreEqual, passwordIsStrongEnough in
                if passwordIsEmpty {
                    return .empty
                } else if !passwordsAreEqual {
                    return .noMatch
                } else if !passwordIsStrongEnough {
                    return .notStrongEnough
                } else {
                    return .valid
                }
            }
            .eraseToAnyPublisher()
    }
    
    /**
     Чтобы установить, является ли имя пользователя username правильным,
     мы преобразуем введенное пользователем имя из String в Bool, используя оператор map.
     
     Результат этого преобразования затем используется  подписчиком  assign, который — как следует из названия —
     назначает полученное значение value выходному (output) свойству isValid нашей Модели UserViewModel.
     
     Оператор debounce позволяет нам сообщить системе, что мы хотим дождаться паузы в доставке событий, например, когда пользователь перестает печатать.
     
     Аналогично, оператор removeDuplicates будет публиковать события, только если они отличаются от любых предыдущих событий.
     Например, если пользователь сначала вводит john, затем joe, а затем снова john, мы получим john только один раз. Это помогает сделать наш UI более эффективным.
     
     Результат этой цепочки вызовов является Cancellable, который мы можем использовать для отмены обработки при необходимости (полезно для длинных цепочек).
     Мы сохраним его (и все остальные, которые мы создадим позже) в множестве Set <AnyCancellable>, которое мы можем очистить при deinit нашего userViewModel.
     */
    private var isUsernameValidPublisher: AnyPublisher<Bool, Never> {
        $username
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { input in
                print(input)
                return input.count >= 3
            }
            .eraseToAnyPublisher()
    }
    
    private var isFormValidPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(isUsernameValidPublisher, isPasswordValidPublisher)
            .map { userNameIsValid, passwordIsValid in
                return userNameIsValid && (passwordIsValid == .valid)
            }
            .eraseToAnyPublisher()
    }
    
    init() {
        /**
         поможем пользователю при заполнении формы регистрации.
         Сначала мы подписываемся subscribe на соответствующих уже полученных издателей Publishers, чтобы узнать,
         когда свойства username и password неправильные (invalid).
         Опять же, нам нужно убедиться, что это происходит на main потоке, то есть на потоке пользовательского интерфейса, п
         оэтому мы вызовем метод receive (on 🙂 и передадим туда значение RunLoop.main.
         */
        isUsernameValidPublisher
            .receive(on: RunLoop.main)
            .map { valid in
                valid ? "": "User name must at least have 3 characters"
            }
            .assign(to: \.usernameMessage, on: self)
            .store(in: &cancellableSet)
        
        isPasswordValidPublisher
            .receive(on: RunLoop.main)
            .map { passwordCheck in
                switch passwordCheck {
                case .empty:
                    return "Password must not be empty"
                case .noMatch:
                    return "Password don't match"
                case .notStrongEnough:
                    return "Password not strong enough"
                default:
                    return ""
                }
            }
            .assign(to: \.passwordMessage, on: self)
            .store(in: &cancellableSet)
        

        /**
         Все, что мы проделали до этого,  совершенно бесполезно, если не подключиться к UI. Чтобы управлять состоянием кнопки «Sign up«,
         нам нужно обновить выходное свойство isValid в нашей Модели UserViewModel.
         Для этого мы просто подписываемся на isFormValidPublisher и присваиваем значения, которые он публикует, свойству isValid
         
         Поскольку этот код взаимодействует с UI, он должен работать на main потоке.
         Мы можем заставить SwiftUI выполнить этот код на main потоке, потоке пользовательского интерфейса, вызвав метод receive (on: RunLoop.main).
         */
        isFormValidPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isValid, on: self)
            .store(in: &cancellableSet)
    }
    
    
    
    
}
