#!/bin/sh

#检查xib中包含而工程中没有的图片资源，
#用法：
#参数1.所有xib所在文件夹；
#参数2.所有图片资源所在文件夹
#结果可重定向到任意文件中



find $1 -name "*.xib" > ./all_XibList.txt

cat ./all_XibList.txt \
|while read line;do
#iname=$(basename "$line" | sed -e "s/\.png//");
#echo "iname=$iname"
grep .png $line

done > ./aaa.txt

#sed 's/imageView/imageView\n/' aaa.txt
#cat ./aaa.txt |tr "=" "\n"


echo "$(cat ./aaa.txt |tr "=" "\n")" > bbb.txt

echo "$(cat ./bbb.txt |tr " " "\n")" > ccc.txt

echo "$(cat ./bbb.txt |tr "\"" "\n")" > ddd.txt

echo "$(cat ./ddd.txt |tr "-" "\n")" > ddd.txt

echo "$(cat ./ddd.txt |tr ">" "\n")" > ddd.txt

echo "$(cat ./ddd.txt |tr "<" "\n")" > ddd.txt



echo "$(grep .png ./ddd.txt)" > ddd.txt

echo "$(sort -n ./ddd.txt | uniq)" > ddd.txt
#sort -n ./ddd.txt | awk '{if($0!=line)print; line=$0}'


find $2 -name "*.png" > ./all_PNGList.txt

cat ./ddd.txt \
|while read line;do
iname=$(basename "$line" | sed -e "s/\.png//");
#echo "iname=$iname"

if ! grep -q $iname ./all_PNGList.txt; then
    echo "$line"
fi

done > eee.txt


project=`find $1 -name '*.?ib'`

cat ./eee.txt \
|while read line;do

echo "$line"
echo "appear in file:"
grep -l $line $project

done

rm ./aaa.txt;
rm ./bbb.txt;
rm ./ccc.txt;
rm ./ddd.txt;
rm ./eee.txt;
rm ./all_PNGList.txt;
rm ./all_XibList.txt
