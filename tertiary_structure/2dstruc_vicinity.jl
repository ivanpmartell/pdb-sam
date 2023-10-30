using BioStructures
using Plots

#Read mutation file (get res numbers)

mutation_locs #dict of mutation from other file

#Get alpha carbons from all cifs (read structures)

calphas = collectatoms(struc, calphaselector)

#plot the mutations 
plot(
    resnumber.(calphas),
    tempfactor.(calphas),
    xlabel="Residue number",
    ylabel="Temperature factor",
    label="",
)

#Obtain vicinity of each mutation (check angstrom distance to use)
vicinity #dict of res_num and list of calphas in its vicinity

for at in calphas
    for res_num in mutation_locs
    if distance(struc['A'][res_num], at) < 5.0 && resnumber(at) != res_num
        println(pdbline(at))#remove line
        #Add to vicinity dict

        #print / write in file the vicinity of each mutation

        #plot the vicinity for each mutation
        plot(
            vicinity #vicinity list for mutation,
            tempfactor.(calphas) #vicinity list for that res number,
            xlabel="Residue number",
            ylabel="Temperature factor",
            label="",
        )
    end
end

