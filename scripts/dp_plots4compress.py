import matplotlib.pyplot as plt
import numpy as np
fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2)

#plt.figure(tight_layout=True, figsize=(8, 8), dpi=150)

data = np.genfromtxt("./lcurve.out", names=True)
#print (data)
for name in data.dtype.names[1:-1]:
    ax1.plot(data['step'], data[name], label=name)
ax1.legend(fontsize=8)
ax1.set_title('Loss')
ax1.grid()
#
fe=np.loadtxt("./temp.e.out")
ff=np.loadtxt("./temp.f.out")
fv=np.loadtxt("./temp.v.out")

ax2.scatter(fe[:,:1].ravel(), fe[:,1:].ravel(),s=3)
left,right =ax2.set_xlim()
ax2.plot([left,right],[left,right],color='black')
ax2.set_title('Energy')
ax2.grid()

ax3.scatter(ff[:,:3].ravel(), ff[:,3:].ravel(),s=3)
left,right =ax3.set_xlim()
ax3.plot([left,right],[left,right],color='black')
ax3.set_title('Force')
ax3.grid()

ax4.scatter(fv[:,:9].ravel(), fv[:,9:].ravel(),s=3)
left,right =ax4.set_xlim()
ax4.plot([left,right],[left,right],color='black')
ax4.set_title('Virial')
ax4.grid()

fig.tight_layout()
plt.savefig("dp_temp.png") 
#plt.show()