# At this point, it is imperative to stop and ensure that the basic functions (compiling and linking) of 
# the new toolchain are working as expected. To perform a sanity check, run the following commands:

echo 'int main(){}' | $LFS_TGT-gcc -xc -;
readelf -l a.out | grep ld-linux;
# If everything is working correctly, there should be no errors, and the output of the last command 
# will be of the form:
####

# [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2];
####
# Note that for 32-bit machines, the interpreter name will be /lib/ld-linux.so.2.

# If the output is not as shown above, or there is no output at all, then something is wrong. 
# Investigate and retrace the steps to find out where the problem is and correct it. This issue must be 
# resolved before continuing.

# Once all is well, clean up the test file:

# rm -v a.out