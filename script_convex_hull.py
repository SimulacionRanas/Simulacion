#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np, matplotlib.pyplot as plt, pylab as p, time, sys
from scipy.spatial import ConvexHull

class snapshot:
    def __init__(self):
        self.interval = 0
        self.id = 0
        self.points = 0
        self.area = 0
        self.ultimo_peso = 0
        self.peso_prom = 0

class interval:
    def __init__(self):
        self.id = 0
        self.agents = 0

def get_intervals(inter):
    # extraigo del csv las marcas
    m = np.loadtxt(open("salida-movimientos.csv","rb"),delimiter=";",skiprows=0)

    # busco la cantidad de ranas y el ultimo tic
    # sumo 1 por el index 0
    cant_ranas = m[:,1].max() + 1
    max_tic = m[:, 0].max() + 1

    set_m = np.vsplit(m, int(inter))

    new_set = np.zeros((len(set_m), 1), dtype=object)

    i = 0
    for m in set_m:
        abc = m[np.argsort(m[:,1])]
        abc = np.vsplit(abc, cant_ranas)

        new_abc = np.zeros((len(abc), 1), dtype=object)
        j = 0
        for a in abc:
            s = snapshot()
            s.interval = i
            s.id = a[0, 1]
            s.ultimo_peso = a[-1, 4]
            s.peso_prom = np.average(a[:, 4])
            s.points = a[:, [2,3]]
            new_abc[j, 0] = s
            j = j + 1

        inter = interval()
        inter.id = i
        inter.agents = new_abc[:, 0]
        new_set[i, 0] = inter
        i = i + 1    
    return new_set

def poly_area(x, y):
    return 0.5*np.abs(np.dot(x,np.roll(y,1))-np.dot(y,np.roll(x,1)))
             
def process_interval(i):
    for agent in i[0].agents:
        process_snap(agent)

def process_snap(s):
    points = s.points
    hull = ConvexHull(points)
    
    # descomentar para graficar
    # TODO: hacerlo más fancy
    plt.plot(points[:,0], points[:,1], 'o')
    for simplex in hull.simplices:
        plt.plot(points[simplex, 0], points[simplex, 1], 'k-')
    s.area = poly_area(points[hull.vertices, 0], points[hull.vertices, 1])
    print(s.area)

if __name__ == "__main__":
    inter = sys.argv[1]
    intervals = get_intervals(inter)

    c = 0
    for interval in intervals:
        plt.figure(c)
        process_interval(interval)
        c = c + 1
    plt.show()
