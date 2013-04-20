from setuptools import setup, find_packages
 
setup(
    name = "biointerchange",
    version = "0.2.1",
    author = "Joachim Baran, Geraint Duck",
    description = ( "Wrapper for easy access to GFF3O, GVF1O, SIO, SO and SOFA.",
                    "Part of the BioInterchange project." ),
    license = "MIT",
    url = "http://www.biointerchange.org",
    packages = find_packages()
    )

