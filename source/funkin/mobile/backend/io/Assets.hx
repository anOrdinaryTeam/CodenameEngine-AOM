package funkin.mobile.backend.io;

#if android
typedef Assets = funkin.mobile.backend.io.android.Assets;
#elseif ios
typedef Assets = funkin.mobile.backend.io.ios.Assets;
#end
