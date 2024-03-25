from pymatgen.ext.matproj import MPRester
from pymatgen.core.composition import Composition
from pymatgen.io.cif import CifWriter
mpr = MPRester("mNc4JkZnltCEqDhU")
elements = mpr.get_materials_ids("BN") #"B-N" for all combinatio
for element in elements:
    structure = mpr.get_structure_by_material_id(element)
    str_ele = str(element)
    w = CifWriter(structure)
    cif_file = str_ele+'.cif'
    w.write_file(cif_file)
