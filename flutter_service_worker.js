'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "57cb712cfc037c07b7df92e07cc209d6",
"assets/AssetManifest.bin.json": "70b6006ba263ebe6f2105ce42b5e82a9",
"assets/AssetManifest.json": "8b1b5e0556df3b778a810fb00cfa6b1f",
"assets/assets/fonts/NotoSansKannada-Regular.ttf": "d41d8cd98f00b204e9800998ecf8427e",
"assets/assets/images/Aarti%2520Swaroop.jpg": "8e84bc3a19da104d564cd8575b5ae776",
"assets/assets/images/Aavahan%2520-%2520Hindi%2520Book.jpg": "0fbcf214a61f1e5053151725af55f1a3",
"assets/assets/images/Abhyarishta%2520-%2520450%2520Ml.jpg": "3cf3eea2bf835b51ab016bfb44af6423",
"assets/assets/images/Agnimukh%2520Churna%2520-%252050%2520Gm.jpg": "fb49f3166e895fc7afdf7fb81bf1b876",
"assets/assets/images/Agnimukh%2520Churna%2520-%252075%2520Gm.jpg": "9fc539f54601592060d696c175184f9c",
"assets/assets/images/Aisa%2520Satguru%2520Mera%2520-%2520Hindi%2520Book.jpg": "fb179cef1e3b6922aa7f00e672d0ec2b",
"assets/assets/images/Akhand%2520Gyan%2520(H)%252025.jpg": "30d1b0b15c133b6fb70593d02f8a68cf",
"assets/assets/images/Aloevera%2520(Bathing%2520Bar).jpg": "44ca109d8a2559206a58f4b3ccf5aa06",
"assets/assets/images/Aloevera%2520Face%2520Wash%2520-%2520200%2520ml.jpg": "08a391a987cb071ac3760f1eb57d7325",
"assets/assets/images/Aloevera%2520Fairness%2520Cream%2520-%2520100%2520Gm.jpg": "f03eee15d0dacbe9376b42ac7c495fdc",
"assets/assets/images/Aloevera%2520Juice%2520-%2520600%2520Ml%2520(Pineapple).jpg": "80d7d14c7a1e1275c49e53b0422aac14",
"assets/assets/images/Aloevera%2520Juice%2520-%2520600ml%2520(Simple).jpg": "231a3662bd90a0f46796c234cba3baff",
"assets/assets/images/Aloevera%2520Shampoo%2520-%2520200%2520Ml.jpg": "355111148ade33accfec1fffa225be48",
"assets/assets/images/Aloevera%2520Skin%2520Gel%252080gm.jpg": "c920d1f3f33bea5e7a6db475f6d0cac9",
"assets/assets/images/Alsi%2520Oil%2520250ml.jpg": "431e9b2fdb1ae1f838db57e1114555fb",
"assets/assets/images/Amla%2520Juice%2520-%2520600ml.jpg": "99169f3cd935f689668b9cfe8a036b73",
"assets/assets/images/Amlant%2520Syrup%2520200ml.jpg": "78e59d05f653889201cf7f9f3cd20210",
"assets/assets/images/Anjan%2520Amrit%2520Eye%2520Drop10ml.jpg": "13377adcc15b26a4ddd1ad6585d9931a",
"assets/assets/images/Anti%2520Hair%2520Fall%2520Hair%2520Oil%2520-%2520100%2520ml.jpg": "4e58694faa6cbcd27a6edd548209d10d",
"assets/assets/images/Arogya%2520Amrit%2520Herbal%2520Tea%2520-%2520115%2520Gm%2520(old).jpg": "bb90b020fb183848d43bce21a3d24871",
"assets/assets/images/Arogya%2520Amrit%2520Herbal%2520Tea%2520-%2520115%2520Gm.jpg": "bb90b020fb183848d43bce21a3d24871",
"assets/assets/images/Arogya%2520Amrit%2520Herbal%2520Tea%2520-%252020%2520Gm.jpg": "a82f0cdd995365bdbaa6a48e22dcb12e",
"assets/assets/images/Ashwagandha%2520Paak%252080%2520Gm.jpg": "b4b5ea562410821c51b2c5b55a56b984",
"assets/assets/images/Asthivajra%2520-%252030%2520Cap.jpg": "5e726b054c7afd3ef89ba833b991644e",
"assets/assets/images/Ayush%2520Kwath%2520-%252085%2520Gm.jpg": "19d839d75bbe6600a0071882f26b92fb",
"assets/assets/images/Badam%2520Oil%252050ml.jpg": "b5935fd722d230216f93e8f50504971d",
"assets/assets/images/Badam%2520Paak%252080%2520Gm.jpg": "f33a868e69ac5f14317e07588b05ce5b",
"assets/assets/images/Bairagan%2520Folding%2520400%2520(Without%2520Bag).jpg": "a41d8065c8fbd12b1e2230a869a35a42",
"assets/assets/images/Bel%2520Sharbat%2520750ml.jpg": "bbe4089f1ed6c98a10e2a11e3e60bb07",
"assets/assets/images/Bhakti%2520Ke%2520Anuthe%2520Rang%2520-%2520Hindi%2520Book.jpg": "fa9537c8d251a377beb2c13b0d2f8b3a",
"assets/assets/images/Bharat%2520Vishav%2520Ka%2520Hriday%2520-%2520Hindi%2520Book.jpg": "f19c09e6f12da7c3c4b4f7b62765ac0e",
"assets/assets/images/Bhringraj%2520Oil%2520-%2520100ml.jpg": "2540507ced6efe17bf22712f66356f81",
"assets/assets/images/Big%2520Bag.jpg": "734ed627bd6c16ddea5270bc466702fd",
"assets/assets/images/Big%2520Night%2520Lamp.jpg": "9fb31a9fc5d2f70b6dfb79eb74c4dae6",
"assets/assets/images/Black%2520Pepper%2520(Kali%2520Mirch)%2520Powder%2520100g.jpg": "2b33990356b214a0677df7079ca5c7d3",
"assets/assets/images/Black%2520Salt%2520(Kala%2520Namak)%2520100g.jpg": "b905dc1f889b2463e3b6d42de25e23b6",
"assets/assets/images/Brahmakoop%2520Jal.jpg": "39a9cdecf205a4bb1c056942ecf000aa",
"assets/assets/images/Brahmi%2520Amla%2520Oil%2520-%2520100ml.jpg": "0be1aeddb3533afe0cd43844074a9264",
"assets/assets/images/Brahmi%2520Badam%2520Sharbat%2520750ml.jpg": "f317265bbecf3e2773a5c7dce0d77b6d",
"assets/assets/images/Candy%2520Cough%2520Drops.jpg": "1eaca504e3a2edc7b86514ac2e64aa20",
"assets/assets/images/Chaitanya%2520-%2520Eng%2520Book.jpg": "00d6d06657cf5f3380888f3603ebf5a5",
"assets/assets/images/Chandan%2520Sharbat%2520750ml.jpg": "db12eaf22e2f87169afb4dedebd544a9",
"assets/assets/images/Charan%2520Paduka%2520Medium.jpg": "1940eb591c7dac441c3e01c263621c55",
"assets/assets/images/Charan%2520Paduka%2520Small.jpg": "55ba665611604629b9f2d93033d3e991",
"assets/assets/images/Chyawanprash%2520(Honey%2520Base)%2520-%2520500%2520Gm.jpg": "4b27d93b6c7ef64c26c0c4ee868f904b",
"assets/assets/images/Chyawanprash%2520Kesar%2520-%25201%2520Kg%2520(old).jpg": "5b685146701a0fe4b14a3abd1e14d34e",
"assets/assets/images/Chyawanprash%2520Kesar%2520-%25201%2520Kg.jpg": "5b685146701a0fe4b14a3abd1e14d34e",
"assets/assets/images/Chyawanprash%2520Kesar%2520-%2520500%2520gm%2520old.jpg": "3f3ae2410713d54d94d29207a008b351",
"assets/assets/images/Chyawanprash%2520Kesar%2520-%2520500%2520gm.jpg": "3f3ae2410713d54d94d29207a008b351",
"assets/assets/images/Chyawanprash%2520Plain%2520-%2520500%2520gm.jpg": "5c363349362763839a08591f363511b4",
"assets/assets/images/Chyawanprash%2520Special%2520with%2520Jaggery%2520-%2520500%2520Gm.jpg": "a88585f5d533cd71d40cc4ccb1529588",
"assets/assets/images/Coconut%2520Oil%2520200ml.jpg": "2a7cb6810cbfe10eeded1aade9c3715a",
"assets/assets/images/Coriander%2520(Dhaniya)%252075g.jpg": "beeb9bf775ade7a934eb2719b94ef493",
"assets/assets/images/Coriander%2520(Dhaniya)%2520Powder%2520100g.jpg": "349322fe2bb11072ebfd890bf3ac6250",
"assets/assets/images/Coriander%2520Powder%2520100g.jpg": "48b14337c6a07c5cfe36309490c9db29",
"assets/assets/images/Creamy%2520(Bathing%2520Bar).jpg": "f09630bd90545f1880fe0f01b215b97c",
"assets/assets/images/Cucumber%2520(Bathing%2520Bar).jpg": "9deadfa39d89e1838978f1f6dee6cdf5",
"assets/assets/images/Dant%2520Shuddhi%2520Manjan%2520-%252050%2520gm.jpg": "21a402a79a6d4f749a03ae792565be14",
"assets/assets/images/Dant%2520Shuddhi%2520Tooth%2520Paste%2520-%2520100%2520Gm.jpg": "a420159e409a66b00ca67ff2982788cc",
"assets/assets/images/Dant%2520Shuddhi%2520Tooth%2520Paste%2520-%252020%2520Gm.jpg": "392a5aeeed61fad2f719ac327983256e",
"assets/assets/images/Dant%2520Shuddhi%2520Tooth%2520Paste%2520-%2520200%2520Gm.jpg": "af57fb52933343b321b9b9480530a41c",
"assets/assets/images/DISH%2520WASH.jpg": "87d1e09a76d5625b53980e29777689a7",
"assets/assets/images/Divya%2520Bhajnawali%2520-%2520Hindi%2520Book.jpg": "d9ef55052114c443460bb4c9d6b21aae",
"assets/assets/images/Divya%2520Guru%2520Ka%2520Divya%2520Vigyan-%2520Hindi%2520Book.jpg": "93ca8e0a84106675068cd1c40d737570",
"assets/assets/images/Divya%2520Gyan%2520Prakash%2520-%2520Hindi%2520Book.jpg": "800f8e7e5d0ee3b7049bedf7ff59cb7a",
"assets/assets/images/Divya%2520Gyan%2520Prakash%2520-%2520Telgu%2520Book.jpg": "2dff252c6f7faa8a62b416bd2b92b8e7",
"assets/assets/images/Divya%2520Sandesh%2520-%2520Hindi%2520Book.jpg": "23c2fcf1b4a64b32c0926fb2e4800f2f",
"assets/assets/images/djf_full.png": "12023e1094c12dc4be3f67cadc77069c",
"assets/assets/images/djf_logo.png": "821775cee8a5a1d557202f8baacad7df",
"assets/assets/images/djjs_logo.png": "7f0a13a32da2198befdafb4208a00d79",
"assets/assets/images/Door%2520Bell.jpg": "ad3d30e8f757164c0f1d11d3beb9155f",
"assets/assets/images/Face%2520Pack%252050gm.jpg": "1b5bc68de1b41fc3afcc97ceefa12a7f",
"assets/assets/images/Farewell%2520To%2520Drugs%2520Forever%2520-%2520Eng%2520Book.jpg": "9ebc08c487319ecf33a96dc44213afd8",
"assets/assets/images/Four%2520Pose%2520Swaroop.jpg": "761e44d54d5add477691c9af6ddc4e0a",
"assets/assets/images/Frequently%2520Asked%2520Questions%2520-%2520Eng%2520Book.jpg": "c894a64e04ac5c8b885f353e9ef588e7",
"assets/assets/images/Fruit%2520Xpert%2520(Gauva%2520Flv.)%2520200ml.jpg": "2596fa13f8e1d03ba293fda19663cf2f",
"assets/assets/images/Fruit%2520Xpert%2520(Gauva%2520Flv.)%2520750ml.jpg": "05347f58c4e9ac34402823c9b2c39fa1",
"assets/assets/images/Fruit%2520Xpert%2520(Kiwi%2520Flv.)%2520200ml.jpg": "8d4d9a85934b9423e5ee6c32b6591890",
"assets/assets/images/Fruit%2520Xpert%2520(Kiwi%2520Flv.)%2520750ml.jpg": "b06727d7efe941126772d70936c9a883",
"assets/assets/images/Fruit%2520Xpert%2520(Litchi%2520Flv.)%2520200ml.jpg": "a1dd3c2b045ad6bd26254db3ba8aa741",
"assets/assets/images/Fruit%2520Xpert%2520(Litchi%2520Flv.)%2520750ml.jpg": "35c1a9d3386a0e339e6a3a99dca8c0ae",
"assets/assets/images/Fruit%2520Xpert%2520(Mango%2520Flv.)%2520200ml.jpg": "6d3bc21fde8d6af03ae7a31b2c521b70",
"assets/assets/images/Fruit%2520Xpert%2520(Mango%2520Flv.)%2520750ml.jpg": "093f1fab4e61b482a0a0823ed51a5b1f",
"assets/assets/images/Fruit%2520Xpert%2520(Strawberry%2520Flv.)%2520200ml.jpg": "da80d5fcad5f6d4551fcda0feb49049b",
"assets/assets/images/Fruit%2520Xpert%2520(Strawberry%2520Flv.)%2520750ml.jpg": "ddb5d6d4c4b95e197ad847a6b99a7de9",
"assets/assets/images/Garam%2520Masala%2520100g.jpg": "1e8a759a9ea77b1660e2864144fe99c7",
"assets/assets/images/Giloy%2520Arq%2520225ml.jpg": "7d15c219f59a831cdaea46dd408e6789",
"assets/assets/images/Giloy%2520Tea%2520100gm.jpg": "db05edc022049fd68da31ddff387a5c2",
"assets/assets/images/Giloy%2520Tea%2520250gm.jpg": "6d50e51871cd2db830444f656ef52be7",
"assets/assets/images/Goat%2520Milk%2520(Bathing%2520Bar).jpg": "5cd5d32aeda2fadc561cb36769ae503e",
"assets/assets/images/Gulab%2520Arq%2520-%2520100%2520ml.jpg": "f99f119899b5b838df21d89bba761ac3",
"assets/assets/images/Gulab%2520Sharbat%2520750ml.jpg": "1e010b5d946c288a9d57712b550cf2fd",
"assets/assets/images/Gulkand%2520500gm.jpg": "d7e1b2c64acddf08addc07655557897c",
"assets/assets/images/Gullak%2520Medium.jpg": "e5b230516e1a13243e3e871bc8803b8c",
"assets/assets/images/Gullak%2520Small.jpg": "e5b230516e1a13243e3e871bc8803b8c",
"assets/assets/images/Guru%2520Kyun%2520Or%2520Kaisa%2520Dharan%2520Kare%2520-%2520Hindi%2520Book.jpg": "b665249e5bd2b5c009699c0f81de6aa4",
"assets/assets/images/Guru%2520Kyun%2520Or%2520Kaisa%2520Dharan%2520Kare%2520-%2520Kannada%2520Book.jpg": "c9b5c5d9f9c444a7c53f8c89c8d4ae9c",
"assets/assets/images/Guru%2520Kyun%2520Or%2520Kaisa%2520Dharan%2520Kare%2520-%2520Marathi%2520Book.jpg": "583fa72f400c86de4a7cb03033d9aec0",
"assets/assets/images/Guru%2520Mureed%2520-%2520Bulleshah%2520-%2520Hindi%2520Book.jpg": "73918073dbf5b59ded6bc40d7c9633ef",
"assets/assets/images/Har%2520Yug%2520Ki%2520Pukaar%2520-%2520Hindi%2520Book.jpg": "9f85aefa8c819ed77eddf9733685d30b",
"assets/assets/images/Hath%2520Kada%2520(Brass).jpg": "491f7ee226aa133027dce26dde4e6ccd",
"assets/assets/images/Hawan%2520Samagri%2520100g.jpg": "dfff3108cdf8c5b8bdc54b7b2eaf334c",
"assets/assets/images/Honey%2520-%2520200gm.jpg": "49d895c780a4c793dd93bd15e32d9c50",
"assets/assets/images/Hum%2520Aur%2520Hamare%2520Aradhay%2520Bhagwan%2520Shiv%2520%2520(K).jpg": "ac81996925228b8a6dc84e949c19e38f",
"assets/assets/images/Hum%2520Aur%2520Hamare%2520Aradhay%2520Bhagwan%2520Shiv%2520-%2520Hindi%2520Book.jpg": "d2bcc93daa1d64d59ac23339f7144784",
"assets/assets/images/Hum%2520Aur%2520Humare%2520Aradhya%2520Shri%2520Ganpati%2520-%2520Hindi%2520Book.jpg": "35f5522d950d90995634e5937a71bc68",
"assets/assets/images/Insightful%2520Chats%2520Offline%2520-%2520Eng%2520Book.jpg": "3c8e24debdc9ec53d4ff19ed70aa06d1",
"assets/assets/images/Jasmine%2520(Bathing%2520Bar).jpg": "e7d3ddf88fefdffdd9d99f704f778742",
"assets/assets/images/Jeera%2520(Cumin)%2520100g.jpg": "78973227250f7d553477671b8fa87ad3",
"assets/assets/images/Jeera%2520(Cumin)%2520Powder%2520100g.jpg": "38a57baacbb3a55bb36ef2b0f25c4196",
"assets/assets/images/Jeera%2520Amrit%2520Sharbat%2520750ml.jpg": "23217de26218ad8fc76f851e75af1fcb",
"assets/assets/images/Jwar%2520Sudha%2520Capsule.jpg": "9613578305d42d4d6acc5f4ae23cbc40",
"assets/assets/images/Kaas%2520Sudha%2520Avleh%2520150GM.jpg": "093efce4a83fe81eda9383b0f64218b9",
"assets/assets/images/Kaasban%2520Syrup%2520100ml%2520(old).jpg": "8b9c7145b02428f1384c534f08212fd3",
"assets/assets/images/Kaasban%2520Syrup%2520100ml.jpg": "8b9c7145b02428f1384c534f08212fd3",
"assets/assets/images/Kaas_Sudha_Avleh_150GM-removebg-preview.jpg": "d41d8cd98f00b204e9800998ecf8427e",
"assets/assets/images/Kamlantak%2520Syrup%2520200%2520ML.jpg": "ac370ef3ae163351f9b51b1250e3a7f0",
"assets/assets/images/Kesar%2520(Bathing%2520Bar).jpg": "722f8ae228aaec6d92fdbd51a43606c8",
"assets/assets/images/Keshwardhana%2520Shampoo%2520200%2520ml.jpg": "72adbfa8fafbffa8445bf9afb1432afe",
"assets/assets/images/Key%2520Hanger.jpg": "9cc09e5d2dc6d487f1dc4d04891101ef",
"assets/assets/images/Key%2520Ring%252015.jpg": "e972a061426264f562b62d5bd0a94872",
"assets/assets/images/Key%2520Ring%252020.jpg": "a856295cdd48222f3c3321eba27351e5",
"assets/assets/images/Kumkumadi%2520oil%2520-%25205%2520ml.jpg": "b28aedc6f5a4bfa92fabfc6d9c10cdce",
"assets/assets/images/Kushaasan.jpg": "2d26870e37a8ecf80848e971be24eaf1",
"assets/assets/images/Kya%2520Ishwar%2520Dikhai%2520Deta%2520Hai%2520-%2520Hindi%2520Book.jpg": "04c24e2d0ed32c45c8f5a623988f14e5",
"assets/assets/images/Kya%2520Ishwar%2520Dikhai%2520Deta%2520Hai%2520-%2520Malyalam%2520Book.jpg": "ba2bae0a0afd08938e1391dd9af2cfa7",
"assets/assets/images/Kya%2520Ishwar%2520Dikhai%2520Deta%2520Hai%2520-%2520Telgu%2520Book.jpg": "821e69eed51416adf57826e527d1a1cc",
"assets/assets/images/Lavender%2520(Bathing%2520Bar).jpg": "ee0ac9fc0e3f08e862cc2599ea31bf82",
"assets/assets/images/Lemon%2520(Bathing%2520Bar).jpg": "e1ed25850db3e748bb2dd1e7be4191c1",
"assets/assets/images/Lemon%2520Tea%2520100gm.jpg": "29494767b6dd2803c11c8de23a1f2c41",
"assets/assets/images/Lemon%2520Tea%2520250gm.jpg": "29494767b6dd2803c11c8de23a1f2c41",
"assets/assets/images/Lets%2520Dive%2520Into%2520the%2520Pool%2520of%2520Devotion%2520-%2520Eng%2520Book.jpg": "b78c4b158f61c1fbb9e7fbb012234e1f",
"assets/assets/images/Locket%252010.jpg": "f6e716cb1cca662410899f0401e83df7",
"assets/assets/images/Locket%2520100.jpg": "3387729052575759159c862f2202c0a6",
"assets/assets/images/LOCKET%252015.jpg": "f676478a06438a40c0affa44f43d38a6",
"assets/assets/images/LOCKET%252020.jpg": "6591b65a4787e3d570b90857e5cea7d8",
"assets/assets/images/LOCKET%252025.jpg": "e4635c756a99610d0e7386a39a6a5b4c",
"assets/assets/images/LOCKET%252030.jpg": "13f95c0f122ab583838659b76caf929e",
"assets/assets/images/Locket%252040.jpg": "5af208c4e013a6b972961c9cc20da705",
"assets/assets/images/Madhumar%2520Drops%2520100%2520ml.jpg": "86097e9318f44e3a48b841ff3dae5e45",
"assets/assets/images/Mahayogi%2520ka%2520Maharahasya%2520-%2520%2520Eng..jpg": "e2d9ca7e07d4219b84dd7e071d975892",
"assets/assets/images/Mala%2520(Braslet)%252025.jpg": "8194227bdddbfbe6d4fad7e592031e64",
"assets/assets/images/Mala%2520(Braslet)%252050.jpg": "3f43a912208e719bd6f4f388bee4c190",
"assets/assets/images/Mala%2520(Yellow+Golden).jpg": "6c3889c7bfdb8c002c036643f36ad670",
"assets/assets/images/Mala%252010.jpg": "a05bd090d6416465296b11e13266314b",
"assets/assets/images/Mala%2520100.jpg": "36f42998ff5fb10d7563deed95827d02",
"assets/assets/images/Mala%2520150.jpg": "9f1097b5190094928f2b09f591975b7e",
"assets/assets/images/Mala%2520200.jpg": "d41d8cd98f00b204e9800998ecf8427e",
"assets/assets/images/Mala%2520250.jpg": "b78116f239d80dab1debff3b10cff2ad",
"assets/assets/images/MALA%252040.jpg": "c15a04693c4d702f02a39e02e1554959",
"assets/assets/images/Mala%252060.jpg": "d02f1ed9ff4a6762dd64184fc286c173",
"assets/assets/images/Medha%2520Shakti%2520-%252030%2520Cap.jpg": "8581881c006805ddba835005458dc878",
"assets/assets/images/Medhohar%2520Arq%2520-%2520500%2520Ml.jpg": "ff2c1986549aa2136c3367719f60b783",
"assets/assets/images/Mehnashini%2520Juice%2520-%2520750%2520ml.jpg": "3587f1c87dfceac6a4f532f5e338a167",
"assets/assets/images/Mind%2520A%2520Double%2520Edge%2520Sword%2520-%2520Eng%2520Book.jpg": "49d6acc7c12d41e0d29256293abcd6cb",
"assets/assets/images/Moisturising%2520&%2520Nourishing%2520Skin%2520Cream%2520-%252050%2520gm.jpg": "1208c86de760c1201c7a789411ff3f2f",
"assets/assets/images/Mulethi%2520Churna%2520-%252075%2520gm%2520old.jpg": "bb578311ff44b2f6d8ca12c7394a3bca",
"assets/assets/images/Mulethi%2520Churna%2520-%252075%2520gm.jpg": "52e42c4148b9218ee189f9c9a9dbe248",
"assets/assets/images/MUSTARD%2520OIL%2520-%25201%2520LTR.jpg": "ddc9af2e652e37cf7fa7cba250c659b9",
"assets/assets/images/MUSTARD%2520OIL%2520-%25205%2520LTR.jpg": "4165ff609eef79de031fbff120802e94",
"assets/assets/images/Nav%2520Varsh%2520Kab%2520Aur%2520Kyu%2520-%2520Hindi%2520Book.jpg": "b7a4bc0dd17a3b28fdb58617bb5d5273",
"assets/assets/images/Neem%2520&%2520Tulsi%2520(Bathing%2520Bar).jpg": "046cda9babaa4376094a1c714f883f58",
"assets/assets/images/Neem%2520Face%2520Wash%2520-%252080%2520gm.jpg": "911645e24d1b9952c90f953020a41c62",
"assets/assets/images/Night%2520Lamp%2520Swaroop%2520100.jpg": "76b3e29aef4b9ecd863ef5fbeddd2230",
"assets/assets/images/Night%2520Lamp%2520Swaroop%2520120.jpg": "c0d0f28c52fd22de56691d5e18043c5c",
"assets/assets/images/Night%2520Lamp%2520Swaroop%252080.jpg": "43c0f10456841b3caf216e48c47a75fe",
"assets/assets/images/Orange%2520(Bathing%2520Bar).jpg": "a33210fc0260230f664bd1cd77b66ae4",
"assets/assets/images/Panchsakar%2520Churna%2520-%252050%2520gm.jpg": "bd43ffe90e4a4729d9575af044e55434",
"assets/assets/images/Path%2520to%2520Eternal%2520Knowledge%2520(Tamil).jpg": "311cd9331591b4cb8a73319843958df3",
"assets/assets/images/payment_qr.jpeg": "69f7800298d0d29311d33d8944a31456",
"assets/assets/images/PEN%252050.jpg": "b5ac9aa6f33f2f303e2a3239e9309c58",
"assets/assets/images/Pine%2520Oil%2520(Concentrate).jpg": "96598182d748341e97585d44ffacce0f",
"assets/assets/images/Pocket%2520Swaroop%252010.jpg": "f56e9c8963b45dd1de272084b94166ba",
"assets/assets/images/Prarthna%2520Swaroop.jpg": "c36be5b1750a7e11df887bcca66d06e9",
"assets/assets/images/Prernadeep%2520Swaroop.jpg": "f86191edf10a1c3940e7cdf6fe1e5eab",
"assets/assets/images/Protein%2520Plus%2520200gm%2520old.jpg": "9d7f26004887d377e83f1c68afe583bf",
"assets/assets/images/Protein%2520Plus%2520200gm.jpg": "9d7f26004887d377e83f1c68afe583bf",
"assets/assets/images/Quiclean%2520(Glass%2520Cleaner).jpg": "ea1535c28f0851405df0c12a1f7c5cd5",
"assets/assets/images/Red%2520Chandan%2520(White%2520Thread)%2520+Chandan%2520Mala.jpg": "58c83573427ba5f0d41c956a360c30d8",
"assets/assets/images/Red%2520Chilli%2520(Lal%2520Mirch)%2520Powder%2520100g.jpg": "bc619f7a178c7f5ce702e90414aa1042",
"assets/assets/images/Reformed%2520Turn%2520Reformers%2520Ord.%2520-%2520Eng%2520Book.jpg": "c7f05d5b1b02cfc63bb8811e15575928",
"assets/assets/images/Rock%2520Salt%2520(Sendha%2520Namak)%2520300g.jpg": "2745ee80171757841cd62100dd7a66b0",
"assets/assets/images/Rock%2520Salt%2520(Sendha%2520Namak)%2520500g.jpg": "fba2a77bbcbef22ba81be40cd56e4377",
"assets/assets/images/Rose%2520(Bathing%2520Bar).jpg": "74841e9df3af2a3b2cc9539c7362d1f2",
"assets/assets/images/Saachi%2520Preet%2520-%2520Hindi%2520Book.jpg": "04cb75b03f70884f91d9d9f5be448f92",
"assets/assets/images/Sandal%2520&%2520Turmeric%2520(Bathing%2520Bar).jpg": "3f3bd8920022205eb9c7a982daf6b53c",
"assets/assets/images/Santra%2520Sharbat%2520750ml.jpg": "1b51917fd86c09101d4a9c75d0862560",
"assets/assets/images/Satya%2520Ki%2520Khoj%2520(Oria).jpg": "7b476e1ba60d0446f7566fd4b1b0f541",
"assets/assets/images/Satya%2520Ki%2520Khoj%2520-%2520Gujrati%2520Book.jpg": "632d5c3d56ee5d2c0030be748bebd450",
"assets/assets/images/Satya%2520Ki%2520Khoj%2520-%2520Hindi%2520Book.jpg": "cae3e1892fff5ed82eb29c93562c56b0",
"assets/assets/images/Satya%2520Ki%2520Khoj%2520-%2520Kannada%2520Book.jpg": "5168d35feb7168506fe89525ee48f171",
"assets/assets/images/Search%2520of%2520Truth%2520-%2520Eng%2520Book.jpg": "25133cecfb469c2cbb90f7db0db66078",
"assets/assets/images/Shadbindu%2520Oil%252010ml.jpg": "e99d8009557c7d2af2662dee46b64df9",
"assets/assets/images/Shakahar%2520Ya%2520Mansahar...%2520-%2520Hindi%2520Book.jpg": "52188ae7f55211e5cd3cdc5566c1b614",
"assets/assets/images/Shankh%2520Pushpi%2520syp%2520-%2520200%2520ml.jpg": "77f8a2f259637751b177d8368a3f4301",
"assets/assets/images/Shine%2520Lotion%252080g.jpg": "62bd432983050b53cfd7ec1de8911a15",
"assets/assets/images/Shoolantak%2520Oil-60%2520Ml.jpg": "ddf8f9ce780444df41bb3561aa63bdd0",
"assets/assets/images/Shuddh%2520Shilajit%2520Resin%252020g.jpg": "7665152131b783ec7d53280502a2e675",
"assets/assets/images/Smadhi!%2520Na%2520Ardhaviram,%2520Na%2520Purnaviram%2520-%2520Hindi%2520Book.jpg": "bce042e47f8a6f247690bb0ec58648e3",
"assets/assets/images/Smadhi!%2520Neither%2520A%2520Comma,%2520Nor%2520A%2520Full%2520Stop!%2520-Eng%2520Book.jpg": "61c108ee6d6b825ff8aecab0817f1eae",
"assets/assets/images/Small%2520Bag.jpg": "80b6e804fd5f912b28d319d813bd7e2e",
"assets/assets/images/SOFT%2520WASH%2520500%2520ML%2520(HAND%2520WASH).jpg": "c7a10042b3ad4daba1cbb2122ab602f9",
"assets/assets/images/Standy%2520big%2520Swaroop.jpg": "2420b24f6742e0cb10659d3bb1d02940",
"assets/assets/images/Standy%2520small%2520Swaroop.jpg": "f037e9f5e9daa46ae9ece4e71c77d015",
"assets/assets/images/Stevia%2520Drop%252010ml.jpg": "c7dc7373d6a86ef890e96357a29a669f",
"assets/assets/images/Strawberry%2520Sharbat%2520750ml.jpg": "ddd770313c82b4eba76a1dcdb79e6721",
"assets/assets/images/Sudharkar%2520Bane%2520Sudharak%2520-%2520Hindi%2520Book.jpg": "c5aa00e91430791852c51c070a248a65",
"assets/assets/images/Swaroop%2520Laminated%2520Photo%2520120%2520(10x12).jpg": "a921fd03f11d93f6c5abf10d76d298b2",
"assets/assets/images/Swaroop%2520Laminated%2520Photo%2520400%2520(16x20).jpg": "c11cdcaa00159e6190993491b5bd64e3",
"assets/assets/images/Swaroop%2520Laminated%2520Photo%252050%2520(5x7).jpg": "c6091d1877a75248780e868ebf882707",
"assets/assets/images/Swaroop%2520Laminated%2520Photo%2520500%2520(20x24).jpg": "82d4840c0a79956d9265fd1326e1ac9b",
"assets/assets/images/Swaroop%2520Laminated%2520Photo%252080%2520(8x10).jpg": "a2e8caa6dcd0eb8dcb3f5bb967e8fc67",
"assets/assets/images/Swaroop%2520Plain%2520Photo%2520100%2520%255B12x15%255D.jpg": "21cc678c47f2685e0287b7c349d85726",
"assets/assets/images/Swp%2520Block%2520120.jpg": "e866f46dd07935d2ad4b39694c7b1b5a",
"assets/assets/images/Swp%2520Block%2520150.jpg": "0ede0c3f297c3373089a23a0d88680d7",
"assets/assets/images/Swp%2520Block%2520170.jpg": "2e8766fcbd125061be83468c0a7cf01c",
"assets/assets/images/Swp%2520Block%252070.jpg": "c8b9467bf11a81aeaadc448413907269",
"assets/assets/images/Swp%2520Block%252080.jpg": "8a9e5331353257fbe514f9dad5cbb70d",
"assets/assets/images/Swp%2520Car%2520Hanger%2520100.jpg": "89ef6c93972b60574fb893fc43404b81",
"assets/assets/images/SWP%2520STICKER%252010.jpg": "995909cc4f1d2d7fe43df1692b8efeb5",
"assets/assets/images/Swp%2520Sticker%252015.jpg": "7c479dd29d448746dd72b65ac0275120",
"assets/assets/images/Swp%2520Sticker%252070.jpg": "f0f58d8a4679c15ade75e068dd12911a",
"assets/assets/images/Table%2520Clock%2520150.jpg": "f102e5c0a19d6c03de5f9fa445eb662c",
"assets/assets/images/The%2520Gems%2520Of%2520Spirituality%2520Ord.%2520-%2520Eng%2520Book.jpg": "36b31768f855a63edb18c8a04928b329",
"assets/assets/images/Til%2520Oil%2520250ml.jpg": "661357d5030305c11786356f11c08f45",
"assets/assets/images/Triphala%2520Churna%2520-%2520500%2520Gm.jpg": "0c26b60834509a45902ce5a4cea79b3a",
"assets/assets/images/Triphala%2520Churna%2520-%252075%2520Gm.jpg": "15ae86c9f4e27e467bb5c9a2ff9cffbf",
"assets/assets/images/Tuf%2520Blue%2520(Toilet%2520Cleaner).jpg": "6832bd880f55774535c8eb0c6f3ef65c",
"assets/assets/images/Tulsi%2520Arq%2520225ml.jpg": "6d7acaf9f806ba7b578d4d2610e6b4a2",
"assets/assets/images/Tulsi%2520Mala.jpg": "2c5d41ee2bbe8feae69d9ae54f45704c",
"assets/assets/images/Tulsi%2520Panchamrit%252030ml.jpg": "0e2dd60497841cf051f3ebd4210a8e12",
"assets/assets/images/Turmeric%2520(Haldi)%2520Powder%2520200g.jpg": "8b4748a07c329c23c842f34062f6e1b9",
"assets/assets/images/Turmeric%2520(Haldi)%2520Powder%2520500g.jpg": "55f82fd3543e118689e828607e25da1a",
"assets/assets/images/Vegitarions%2520&%2520Non-Vegetarions%2520-%2520Eng%2520Book.jpg": "5fdcd54c95c45108c71083f15aaa154f",
"assets/assets/images/Wall%2520Clock%2520300.jpg": "b3a465e00daf5c6e4634a022c8b33f5f",
"assets/assets/images/Wall%2520Clock%2520400.jpg": "4e1179f71e3b528ab023bea371107af5",
"assets/assets/images/Wall%2520Clock%2520450.jpg": "b3a330b6c3480b9ab16fa3e4d9f51497",
"assets/assets/images/Why%2520and%2520What%2520Sort%2520of%2520Spiritual%2520Guru%2520-%2520Eng%2520Book.jpg": "68f8f0a03b7773d5ebc6c14360a679c3",
"assets/assets/images/Wooden%2520Jhulla%2520800.jpg": "078bd18607da49408ab274953d93b4c6",
"assets/assets/images/Wooden%2520Jhulla%2520Medium.jpg": "6f0969f541103b0832104508b3aa2a3b",
"assets/assets/images/Yakritrakshak%2520-%252030%2520Cap.jpg": "148cebe5521f317fe0e6bc041b4850ea",
"assets/assets/images/Yograj%2520Gugglu%2520-%252060%2520Tab.jpg": "7d97f73700cb2110d47645a0834282b5",
"assets/assets/sampleapp-456304-0e65d6f57b51.json": "6111ce8d2b20429075c41229449c5fdd",
"assets/FontManifest.json": "9c68d37db15c775b773633423a2ffd94",
"assets/fonts/MaterialIcons-Regular.otf": "e940a46f37d4a0fdb04b5c799a75cc86",
"assets/NOTICES": "32125908eca2b66d1a51593f42d88ffc",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "83572a344ac40aea16e0c1213d402ad9",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "561b7f480e72d23602cc976eff93e6ad",
"/": "561b7f480e72d23602cc976eff93e6ad",
"main.dart.js": "35a26a07d801de396af47a814b853704",
"manifest.json": "c4cd1337db9da283a8433de90fb18b19",
"version.json": "047eb19cacf20a3b9b58bc43dce89e3f"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
