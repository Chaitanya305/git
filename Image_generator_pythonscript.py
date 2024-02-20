# Online Python-3 Compiler (Interpreter)
with open("file.txt", 'r') as f:
    lines=f.readlines()
    Nlines=[]
    for index, i in enumerate(lines):
        if index < 3 :
            i=i.strip("\n")
            Nlines.append(i)
        else:
            break
    #lines=[j.strip("\n") if i < 2 else break for i, j in enumerate(lines)]
    #print (lines)
    print(Nlines)
    
## for python version  
line1=Nlines[0]
print (line1.split(" "))
p_v = line1.split(" ")[2]
print(p_v.capitalize())
#for R version 
line2=Nlines[1]
print (line2.split(" "))
r_v = line2.split(" ")[2]
print(r_v.capitalize())
#base os
line3=Nlines[2]
print (line3.split(" "))
base_os = line3.split(" ")[2]
print(base_os)

if p_v!=False and r_v!=False:
    print ("logic to build docker image for p and R both")
elif p_v!=False and r_v==False:
    print("logic to build python image alone")
elif p_v==False and r_v!==False:
    print("logic to build R image alone")
else:
    print ("provide correct details")
