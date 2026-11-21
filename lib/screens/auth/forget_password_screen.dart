// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:hoorain_pos/constants.dart';
// import 'package:hoorain_pos/controllers/login_controller.dart';
// import '../../utils/toas_message.dart';
// import '../../widgets/backbutton.dart';
// import '../../widgets/primary_textfield.dart';
// import '../../widgets/round_button.dart';

// class ForgotPasswordScreen extends StatefulWidget {
//   const ForgotPasswordScreen({super.key});

//   @override
//   State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
// }

// class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
//   TextEditingController emailController = TextEditingController();
//   final LoginController signupController = Get.put(LoginController());

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: BackNavigatingButton(color: kPrimaryColor,),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 40.h),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [

//               SizedBox(
//                 height: Get.height*.17.h,
//               ),
//               // Title
//               Text(
//                 'Forgot Password?',
//                 textAlign: TextAlign.center,
//                 style: GoogleFonts.lora(
//                   color: Color(0xFF1B1A1F),
//                   fontSize: 28.sp,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               SizedBox(height: 10.h),
//               // Subtitle
//               Text(
//                 'Enter your email address to receive instructions',
//                 textAlign: TextAlign.center,
//                 style: GoogleFonts.interTight(
//                   color: Color(0xFF737A97),
//                   fontSize: 14.sp,
//                   fontWeight: FontWeight.w400,
//                 ),
//               ),
//               SizedBox(height: 49.h),

//               // Email TextField
//               PrimaryTextField(
//                 controller: emailController,
//                 fieldType: TextInputType.emailAddress,
//                 hintText: 'Enter your email',
//                 headerText: 'Email',
//               ),
//               SizedBox(height: 30.h),

//               // Reset Button
//               Obx(
//                 () => Center(
//                   child: RoundButton(
//                     onPressed: () {
//                       if (emailController.text.isEmpty) {
//                         MessageToast.showToast(
//                           msg: 'Please enter your email',
//                         );
//                       } else {
//                         signupController.forgotPassword(
//                           emailController.text.trim(),
//                         );
//                       }
//                     },
//                     text: 'Reset',
//                     isLoading: signupController.isLoading.value,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
