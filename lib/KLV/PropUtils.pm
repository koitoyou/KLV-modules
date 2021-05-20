package KLV::PropUtils;
use strict;
use Encode;
use JSON;

#===============================================================================
#
# JSON形式のプロパティファイルを読み込んでPerlのハッシュに変換して返す
#
# 引数 $file   JSONファイル
#
# 戻り値 成功時: ハッシュへのリファレンス
#        失敗時: undef
#
#===============================================================================
sub load_property($) {
  my $file = shift;

  if ( open FILE, "<", $file ) {
    my $json_str = '';
    while ( <FILE> ) {
      my $line = $_;
      if ( $line =~ /^\s*\#/ or $line =~ /^\s*\/\// ) {
        #コメント行対応
        #本来JSON形式にはコメントを書くことはできないが独自拡張として
        #シャープ(#)および//から始まる行はコメント行とみなす
        next;
      }
      $json_str .= $line;
    }
    close FILE;

    my $json_str_utf8 = Encode::encode('utf8',$json_str);  # utf8フラグOFF
    my $data = undef;
    eval { $data = from_json($json_str); };
    if ( $@ ) {
      # エラー処理
      return undef;
    }

    if ( ref($data) eq 'HASH' and exists $data->{CONST} and ref($data->{CONST}) eq 'HASH' ) {
      # $dataがハッシュのリファレンス　且つ　$data->{CONST}がハッシュとして定義されていること
      # 変数変換を行う

      # 無名関数 : %%～%%をCONST内の定義に置換する
      my $trans_func = sub ($) {
        my $val = shift;
        if ( $val =~ /\%\%([A-Z0-9_]+)\%\%/ ) {
          my $key = $1;
          if ( exists $data->{CONST}->{$key} ) {
            return $data->{CONST}->{$key};
          }
        }
        return $val;
      };
      _transval($trans_func, $data);
    }

    return $data;
  }

  return undef;
}
sub _transval($$) {
  my $func   = shift;
  my $valref = shift;

  if ( ref($valref) eq 'HASH' ) {
    foreach my $key ( keys %{$valref} ) {
      if ( ref($valref->{$key}) ) {
        # 値がリファレンスのときは再帰呼び出し
        _transval($func,$valref->{$key});
      } else {
        # リファレンスでないときは無名関数呼び出し
        $valref->{$key} = $func->($valref->{$key});
      }
    }
  } elsif ( ref($valref) eq 'ARRAY' ) {
    foreach my $val ( @{$valref} ) {
      if ( ref($val) ) {
        # 値がリファレンスのときは再帰呼び出し
        _transval($func,$val);
      } else {
        # リファレンスでないときは無名関数呼び出し
        $val = $func->($val);
      }
    }
  }
}

#===============================================================================
#
# PerlのハッシュをJSON形式に変換して、ファイルに保存する
#
# 引数 $file   JSONファイル
#      $hash   ハッシュへのリファレンス
#
# 戻り値 成功時: 1
#        失敗時: 0
#
#===============================================================================
sub save_property($$) {
  my $file = shift;
  my $hash = shift;

  my $json = '';
  eval { $json = to_json($hash,{pretty=>1}); };
  if ( $@ ) {
    # エラー処理
    return 0;
  }

  if ( open FILE, ">", $file ) {
    print FILE $json;
    close FILE;
    return 1;
  }

  return 0;
}

1;
