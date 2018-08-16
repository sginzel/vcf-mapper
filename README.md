# vcf-mapper

## Installation
### From source to gemfile
  gem build vcf-mapper.gemspec
### From gemfile
  gem install --rdoc --ri vcf-mapper

## Documentation
  gem server
  Then open http://0.0.0.0:8808/ in a web browser

## Options
```
  -a, --command=[string]      Action to perform (map, translate, rank)
  -f, --from=[string]         From attribute
  -t, --to=[string]           To attribute
  -c, --chain=[string]        Chain of functions to apply to translated attributes
                         (add|substract|multiply|divide|round|ceil|rank|rank_r|log|log2|log10|phred|from_phred|cat|gsub|external|tof|toi|tos)
  -p, --parameter=[string]    Parameter for translate and grep. Each function required a parameter
  -m, --man=[string]          Show help for a command
  -i, --in=[string]           Input VCF
  -o, --out=[string]          Output VCF
  -h, --help             Show this message
```
## Actions

All examples shown here presume that a pipe is used to feed the input into the vcf-mapper.

### map

Map attributes from INFO:*, FORMAT:* and individual samples to another another field. This is mostly useful to copy fields to a different name.

  Example 1 (map an INFO field to another name): 
  ```
   vcf-mapper -a map -f INFO:VT -t INFO:BLUB
  
  Input: 
    1       38384063        .       C       A       .       PASS    SOMATIC GT:AD:BQ:DP:FA                 0/1:48,7:14.0:55:0.127
    1       38384064        .       C       A       .       REJECT  SOMATIC;VT=SNP GT:AD:BQ:DP:FA          0/1:48,7:14.0:55:0.127
  Output: 
    1       38384063        .       C       A       .       PASS    SOMATIC GT:AD:BQ:DP:FA                     0/1:48,7:14.0:55:0.127
    1       38384064        .       C       A       .       REJECT  SOMATIC;VT=SNP;BLUB=SNP GT:AD:BQ:DP:FA     0/1:48,7:14.0:55:0.127
  
  Example 2 (map the genotype fields) 
    vcf-mapper -a map -f FORMAT:DP -t FORMAT:TEST 
  
  Input:
    1       38184163        .       C       A       .       PASS    .       GT:AD:BQ:DP:FA          0:57,3:0.0:62:0.05      0/1:48,7:14.0:55:0.127:55
  Output:
    1       38184163        .       C       A       .       PASS    .       GT:AD:BQ:DP:FA:TEST     0:57,3:0.0:62:0.05:62   0/1:48,7:14.0:55:0.127:55
  
  Example 3 (map only a specific genotype) 
    vcf-mapper -a map -f SMPL1:DP -t SMPL1:TEST 
  
  Input:
    #CHROM  POS             ID      REF     ALT     QUAL    FILTER  INFO    FORMAT             SMPL1                SMPL2
    1       38184163        .       C       A       .       PASS    .       GT:AD:BQ:DP:FA     0:57,3:0.0:62:0.05   0/1:48,7:14.0:55:0.127:55
  Output:
    1       38184163        .       C       A       .       PASS    .       GT:AD:BQ:DP:FA:TEST     0:57,3:0.0:62:0.05:62   0/1:48,7:14.0:55:0.127:55:.
```

The meta information is copied when using map.
```
  Input: 
    ##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Approximate read depth (reads with MQ=255 or with bad mates are filtered)">
  Output:
    ##FORMAT=<ID=TEST,Number=1,Type=Integer,Description="Approximate read depth (reads with MQ=255 or with bad mates are filtered)">
```

### translate 
Translate the value of CHROM, POS, ID, REF, ALT, QUAL, FILTER:*, INFO:* and FORMAT:* fields using command chains. 
```
  Example 1 (add one to POS field and append _test - not really useful though): 
   vcf-mapper -a translate -f POS -c "add|cat" -p "1|_test"
  
  Input: 
    1       38184163        .       C       A       .       PASS    .       GT:AD:BQ:DP:FA  0:57,3:0.0:62:0.05      0/1:48,7:14.0:55:0.127
  Output: 
    1       38184164_test   .       C       A       .       PASS    .       GT:AD:BQ:DP:FA  0:57,3:0.0:62:0.05      0/1:48,7:14.0:55:0.127
```
### rank
```Not implemented.```

### Combining actions
```
  Example 1 (map VT field to TYPE field and convert SNP to snv): 
   vcf-mapper -a map -f INFO:VT -t INFO:TYPE | vcf-mapper -a translate -f INFO:TYPE -c "gsub|downcase" -p "SNP,SNV|"
  Input: 
    1       38184164        .       C       A       .       REJECT  SOMATIC;VT=SNP          GT:AD:BQ:DP:FA    0/1:48,7:14.0:55:0.127
  Output: 
    1       38184164        .       C       A       .       REJECT  SOMATIC;VT=SNP;TYPE=snv GT:AD:BQ:DP:FA    0/1:48,7:14.0:55:0.127
  
  Example 2 (map VT field to TYPE field and call date function to add the current date):
    vcf-mapper -a map -f INFO:VT -t INFO:TYPE | vcf-mapper -a translate -f INFO:DATE -c "external" -p "date"
  Input:
    1       38030795        .       C       A       .       PASS    SOMATIC;VT=SNP                                       GT:AD:BQ:DP:FA:SS       0:60,0:0.0:60:0.0:0     0/1:50,4:32.0:54:0.074:2
  Output:
    1       38030795        .       C       A       .       PASS    SOMATIC;VT=SNP;DATE=Do 19. Nov 18:31:22 CET 2015     GT:AD:BQ:DP:FA:SS       0:60,0:0.0:60:0.0:0     0/1:50,4:32.0:54:0.074:2

  Example 3 (map VT field to TYPE field and call echo function to duplicate the entry, please not that a , seperates the placeholder from the actual external command):
    vcf-mapper -a map -f INFO:VT -t INFO:TYPE | vcf-mapper -a translate -f INFO:TYPE -c "external" -p "echo -n,{}/{}"
  Input:
    1       38030795        .       C       A       .       PASS    SOMATIC;VT=SNP                                       GT:AD:BQ:DP:FA:SS       0:60,0:0.0:60:0.0:0     0/1:50,4:32.0:54:0.074:2
  Output:
    1       38030795        .       C       A       .       PASS    SOMATIC;VT=SNP;TYPE=SNP/SNP     GT:AD:BQ:DP:FA:SS       0:60,0:0.0:60:0.0:0     0/1:50,4:32.0:54:0.074:2
```

## Chain Commands
```
[add] add integer (Example: -p 1)
[substract] substract integer (Example: -p 1)
[multiply] multiply field. Performs floating point operation (Example: -p 1.5)
[divide] divide field by number. Performs floating point operation. (Example: -p 1.4)
[round] round field value. Default is 0. (Example: -p 3 - rounds to third position)
[ceil] ceidl field value. Default is 0 (Example: -p 3 - ceils up to third position)
[log] Log normal transformation (no parameters)
[log2] Log2 transformation (no parameters)
[log10] Log10 transformation (no parameters)
[phred] Phredscale (no parameters)
[from_phred] convert phred scale to floating point. (no parameters)
[cat] concat field with params. (Example: -p sometext,to,concant)
[gsub] Replace pattern with a text. (Example: -p pattern,replacement)
[upcase] convert to upper case (no parameters)
[downcase] convert to lower case (no parameters)
[tof] convert to float (no parameters)
[toi] convert to integer (no parameters)
[toc] convert to character/string (no parameters)
[tos] convert to string (no parameters)
[external] Call a external script. {} is replaced with the field value. (Example: -p date or -p echo -n,{})
```